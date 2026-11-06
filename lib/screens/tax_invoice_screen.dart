import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/order.dart';
import '../state/app_state.dart';
import '../services/auth_service.dart';
import '../widgets/user_avatar.dart';
import 'help_screen.dart';

class TaxInvoiceScreen extends StatefulWidget {
  final UserOrder order;

  const TaxInvoiceScreen({super.key, required this.order});

  @override
  State<TaxInvoiceScreen> createState() => _TaxInvoiceScreenState();
}

class _TaxInvoiceScreenState extends State<TaxInvoiceScreen> {
  bool _isDownloading = false;
  bool _isEmailing = false;

  String _numberToWords(int n) {
    if (n == 0) return 'zero';
    final ones = [
      '', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine',
      'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen',
      'seventeen', 'eighteen', 'nineteen'
    ];
    final tens = [
      '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'
    ];

    String convert(int num) {
      if (num < 20) return ones[num];
      if (num < 100) {
        return tens[num ~/ 10] + (num % 10 != 0 ? ' ${ones[num % 10]}' : '');
      }
      if (num < 1000) {
        return '${ones[num ~/ 100]} hundred${num % 100 != 0 ? ' and ${convert(num % 100)}' : ''}';
      }
      return '${convert(num ~/ 1000)} thousand${num % 1000 != 0 ? ' ${convert(num % 1000)}' : ''}';
    }

    return convert(n);
  }

  String get _cleanOrderDisplayId {
    if (widget.order.displayId.isNotEmpty &&
        widget.order.displayId.length <= 20 &&
        !RegExp(r'^[a-fA-F0-9]{20,}$').hasMatch(widget.order.displayId)) {
      return widget.order.displayId;
    }
    return widget.order.shortOrderNumber;
  }

  List<int> _buildPdfBytes(String userName, String userEmail) {
    final orderNum = _cleanOrderDisplayId;
    final date = widget.order.dateDisplay;
    final total = 'INR ${widget.order.total.toInt()}';

    final buffer = StringBuffer();
    buffer.writeln('%PDF-1.4');
    buffer.writeln('1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj');
    buffer.writeln('2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj');
    buffer.writeln(
        '3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >> endobj');

    final content = StringBuffer();
    content.writeln('BT');
    content.writeln('/F1 20 Tf');
    content.writeln('50 780 Td (PickleO - Tax Invoice) Tj');
    content.writeln('/F1 11 Tf');
    content.writeln('0 -32 Td (Order ID: #$orderNum) Tj');
    content.writeln('0 -20 Td (Invoice Date: $date) Tj');
    content.writeln('0 -20 Td (Billed To: $userName) Tj');
    content.writeln('0 -20 Td (Email: $userEmail) Tj');
    content.writeln(
        '0 -20 Td (Delivery Address: ${widget.order.deliveryAddress.shortAddress}) Tj');
    content.writeln('0 -20 Td (Payment Method: ${widget.order.paymentMethod}) Tj');
    content.writeln('0 -20 Td (Place of Supply: Karnataka | GSTIN: 29AABCP1234F1Z5) Tj');
    content.writeln('0 -28 Td (----------------------------------------------------------------------) Tj');
    for (final it in widget.order.items) {
      final line = '${it.product.name} (${it.selectedWeight}) x${it.quantity}  --  INR ${it.totalPrice.toInt()}';
      content.writeln('0 -18 Td ($line) Tj');
    }
    content.writeln('0 -20 Td (----------------------------------------------------------------------) Tj');
    content.writeln('0 -20 Td (Taxable Value: INR ${widget.order.taxableValue.toInt()}) Tj');
    content.writeln('0 -18 Td (CGST @ 6%: INR ${widget.order.cgst.toInt()}) Tj');
    content.writeln('0 -18 Td (SGST @ 6%: INR ${widget.order.sgst.toInt()}) Tj');
    content.writeln('0 -18 Td (Packaging & Delivery: INR ${widget.order.fees.toInt()}) Tj');
    content.writeln('/F1 14 Tf');
    content.writeln('0 -26 Td (Grand Total: $total) Tj');
    content.writeln('ET');

    final contentStr = content.toString();
    final contentBytes = utf8.encode(contentStr);

    buffer.writeln('4 0 obj << /Length ${contentBytes.length} >> stream');
    buffer.write(contentStr);
    buffer.writeln('endstream endobj');
    buffer.writeln(
        '5 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj');
    buffer.writeln('xref');
    buffer.writeln('0 6');
    buffer.writeln('0000000000 65535 f ');
    buffer.writeln('0000000010 00000 n ');
    buffer.writeln('0000000063 00000 n ');
    buffer.writeln('0000000122 00000 n ');
    buffer.writeln('0000000250 00000 n ');
    buffer.writeln('0000000350 00000 n ');
    buffer.writeln('trailer << /Size 6 /Root 1 0 R >>');
    buffer.writeln('startxref');
    buffer.writeln('450');
    buffer.writeln('%%EOF');

    return utf8.encode(buffer.toString());
  }

  Future<void> _handleDownloadPdf(
      BuildContext context, AppState appState) async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    final orderNum = _cleanOrderDisplayId;
    final fileName = 'PickleO_Invoice_$orderNum.pdf';

    try {
      final pdfBytes = _buildPdfBytes(appState.userName, appState.userEmail);

      String savedLocation = 'Downloads / Internal Storage';
      if (!kIsWeb) {
        try {
          final tempDir = Directory.systemTemp;
          final file = File('${tempDir.path}/$fileName');
          file.writeAsBytesSync(pdfBytes);
          savedLocation = file.path;
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() => _isDownloading = false);

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.leafGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: AppColors.leafGreen,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Invoice PDF Downloaded',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    fileName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.leafGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Saved to: $savedLocation',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _showDocumentPreview(context, appState);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.leafGreen),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: Text(
                            'Preview Document',
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.leafGreen,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.leafGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: Text(
                            'Done',
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (_) {
      if (mounted) setState(() => _isDownloading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to download invoice. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _handleEmailInvoice(BuildContext context, AppState appState) {
    final emailController = TextEditingController(
      text: appState.userEmail.isNotEmpty
          ? appState.userEmail
          : 'customer@pickleo.co.in',
    );
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final mq = MediaQuery.of(context);
            final bottomInset = mq.viewInsets.bottom;
            final systemBottom = mq.padding.bottom;
            final effectiveBottom = bottomInset > 0
                ? (bottomInset + 16)
                : (systemBottom > 0 ? (systemBottom + 16) : 24.0);
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                effectiveBottom,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Email Tax Invoice',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'We will email the official GST invoice for Order #$_cleanOrderDisplayId directly to your inbox.',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Destination Email',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Enter recipient email address',
                        prefixIcon: const Icon(Icons.mail_outline, size: 18),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.borderCard),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.leafGreen, width: 1.5),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter an email address';
                        }
                        if (!val.contains('@') || !val.contains('.')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isEmailing
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => _isEmailing = true);
                                final targetEmail = emailController.text.trim();

                                try {
                                  await AuthService()
                                      .emailOrderInvoice(
                                        orderId: widget.order.id,
                                        email: targetEmail,
                                      )
                                      .timeout(const Duration(seconds: 2));
                                } catch (_) {}

                                if (!mounted) return;
                                if (ctx.mounted) {
                                  setModalState(() => _isEmailing = false);
                                  Navigator.of(ctx).pop();
                                }

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.mark_email_read_outlined,
                                            color: Colors.white, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Tax invoice emailed to $targetEmail',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: AppColors.leafGreen,
                                    duration: const Duration(seconds: 3),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              }
                            },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.leafGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isEmailing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Send Invoice PDF',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDocumentPreview(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceLow,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf,
                        size: 20, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PickleO_Invoice_$_cleanOrderDisplayId.pdf',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.borderCard),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TAX INVOICE',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.leafGreen.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'ORIGINAL FOR RECIPIENT',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.leafGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Text(
                            'Order ID: #$_cleanOrderDisplayId',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Date: ${widget.order.dateDisplay}',
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                          Text(
                            'Billed To: ${appState.userName}',
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 10),
                          ...widget.order.items.take(4).map(
                                (it) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${it.product.name} x${it.quantity}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(fontSize: 11),
                                        ),
                                      ),
                                      Text(
                                        '₹${it.totalPrice.toInt()}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Grand Total',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '₹${widget.order.total.toInt()}',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.leafGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.verified_user,
                                  size: 14, color: AppColors.leafGreen),
                              const SizedBox(width: 4),
                              Text(
                                'Digitally Verified GST Compliant Invoice',
                                style: GoogleFonts.poppins(
                                  fontSize: 9.5,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.leafGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Close',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final totalInt = widget.order.total.toInt();
    final words = 'Rupees ${_numberToWords(totalInt)} only';
    final orderNum = _cleanOrderDisplayId;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Tax Invoice',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: const [
          UserAvatar(radius: 16),
          SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          children: [
            // Authentic GST Invoice Paper Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderCard),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Invoice Header Strip
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: AppColors.surfaceLow,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tax Invoice',
                                style: GoogleFonts.lora(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(
                                      text: widget.order.displayId.isNotEmpty
                                          ? widget.order.displayId
                                          : widget.order.id));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Order ID copied to clipboard'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Order #$orderNum',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Text(
                                'Dated ${widget.order.dateDisplay}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.asset(
                                    'assets/images/app-icon.png',
                                    width: 24,
                                    height: 24,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'PickleO',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF003820),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'PickleO Foods Pvt. Ltd.\nGSTIN 29AABCP1234F1Z5\nFSSAI 10020042000000',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.poppins(
                                fontSize: 9.5,
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Billed To & Order Details Grid
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.surfaceHighest,
                          style: BorderStyle.solid,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BILLED TO',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                appState.userName,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.order.deliveryAddress.fullAddress,
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ORDER',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(
                                      text: widget.order.displayId.isNotEmpty
                                          ? widget.order.displayId
                                          : widget.order.id));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Order ID copied to clipboard'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                child: Text(
                                  '#$orderNum',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Paid via ${widget.order.paymentMethod}\nPlace of supply: Karnataka',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Itemized Table Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'ITEM · HSN 2001',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 44,
                                child: Text(
                                  'QTY',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 70,
                                child: Text(
                                  'AMOUNT',
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        // Item rows
                        ...widget.order.items.map((it) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        it.product.name,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '${it.selectedWeight} · ${it.product.maker}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 44,
                                  child: Text(
                                    '${it.quantity}',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 70,
                                  child: Text(
                                    '₹${it.totalPrice.toInt()}',
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  // Calculations
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: AppColors.surfaceLowest,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _calcRow('Taxable value',
                            '₹${widget.order.taxableValue.toInt()}'),
                        const SizedBox(height: 6),
                        _calcRow(
                            'CGST @ 6%', '₹${widget.order.cgst.toInt()}'),
                        const SizedBox(height: 6),
                        _calcRow(
                            'SGST @ 6%', '₹${widget.order.sgst.toInt()}'),
                        const SizedBox(height: 6),
                        _calcRow('Packaging & delivery',
                            '₹${widget.order.fees.toInt()}'),
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Grand Total',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '₹${widget.order.total.toInt()}',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          words,
                          style: GoogleFonts.lora(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons (Download PDF & Email Invoice)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      key: const Key('download_pdf_button'),
                      onPressed: _isDownloading
                          ? null
                          : () => _handleDownloadPdf(context, appState),
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download, size: 18),
                      label: Text(
                        _isDownloading ? 'Downloading...' : 'Download PDF',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.leafGreen,
                        disabledBackgroundColor:
                            AppColors.leafGreen.withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      key: const Key('email_invoice_button'),
                      onPressed: () => _handleEmailInvoice(context, appState),
                      icon: const Icon(Icons.mail_outline, size: 18),
                      label: Text(
                        'Email Invoice',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: AppColors.leafGreen, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Footer
            Text(
              'This is a computer-generated invoice and does not require a signature.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 2),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HelpScreen()),
                );
              },
              child: Text(
                'Need a correction? Contact support',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.leafGreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _calcRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
