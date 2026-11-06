import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final Map<int, bool> _expandedFaqs = {};

  final List<Map<String, dynamic>> _faqs = [
    {
      'icon': Icons.local_shipping_outlined,
      'q': 'Where is my order?',
      'a': 'You can track your batch directly in the Orders tab or via the real-time courier SMS link sent upon dispatch.',
    },
    {
      'icon': Icons.broken_image_outlined,
      'q': 'A jar arrived broken or leaking',
      'a': 'We provide a 100% no-questions-asked replacement for damaged ceramic or glass jars. Just send a picture to our WhatsApp support within 24 hours of delivery.',
    },
    {
      'icon': Icons.schedule_outlined,
      'q': 'How long do pickles stay fresh?',
      'a': 'Because we use traditional sun-curing and cold-pressed pure oils without preservatives, our pickles stay flavorful for 9 to 12 months when stored using a dry spoon.',
    },
    {
      'icon': Icons.edit_location_outlined,
      'q': 'Change delivery address after ordering',
      'a': 'Address adjustments can be made within 30 minutes of placing your order through WhatsApp support before dispatch.',
    },
    {
      'icon': Icons.receipt_long_outlined,
      'q': 'Refunds, returns and GST invoices',
      'a': 'GST invoices are available instantly inside every order detail. Refunds for eligible returns are processed to your original payment method in 2 to 4 business days.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Help & Support',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 2 Quick Contact Cards
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Opening WhatsApp Support (+91 98765 00000)...'),
                          backgroundColor: AppColors.leafGreen,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.leafGreen,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.chat_outlined,
                              size: 26, color: Color(0xFF95D4AC)),
                          const SizedBox(height: 8),
                          Text(
                            'Chat on WhatsApp',
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Replies in under 5 min',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.outlineVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Calling Helpline: 1800-PICKLE-O...'),
                          backgroundColor: AppColors.textPrimary,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderCard),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.call_outlined,
                              size: 26, color: AppColors.orangeDark),
                          const SizedBox(height: 8),
                          Text(
                            'Call Support',
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '8 AM – 10 PM, all days',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Common Questions Title
            Text(
              'COMMON QUESTIONS',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),

            // FAQ List Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderCard),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _faqs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _faqs[index];
                  final isExpanded = _expandedFaqs[index] ?? false;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _expandedFaqs[index] = !isExpanded;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(item['icon'] as IconData,
                                  size: 20, color: AppColors.orangeDark),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item['q'] as String,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Icon(
                                isExpanded
                                    ? Icons.expand_less
                                    : Icons.chevron_right,
                                size: 20,
                                color: AppColors.outline,
                              ),
                            ],
                          ),
                          if (isExpanded) ...[
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.only(left: 32),
                              child: Text(
                                item['a'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
