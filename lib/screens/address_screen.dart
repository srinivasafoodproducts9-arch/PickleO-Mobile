import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/user_avatar.dart';
import 'address_edit_screen.dart';
import '../utils/auth_guard.dart';

class AddressScreen extends StatefulWidget {
  final bool isSelectMode;

  const AddressScreen({super.key, this.isSelectMode = false});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final appState = AppStateProvider.of(context);
        if (!appState.hasLoadedAddresses && !appState.isLoadingAddresses) {
          appState.loadAddressesFromApi();
        }
      }
    });
  }

  Widget _buildHeaderAvatar(AppState appState) {
    return const UserAvatar(radius: 16);
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final addresses = appState.addresses;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Saved Addresses',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: (appState.isLoadingAddresses ||
                appState.deletingAddressId != null)
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(
                  backgroundColor: AppColors.surfaceContainer,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.pickleOrange),
                  minHeight: 3,
                ),
              )
            : null,
        actions: [
          _buildHeaderAvatar(appState),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => appState.loadAddressesFromApi(),
        color: AppColors.pickleOrange,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        child: Column(
          children: [
            // Top Count & Add New Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  addresses.isEmpty
                      ? 'No addresses saved'
                      : '${addresses.length} saved address${addresses.length == 1 ? '' : 'es'}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    requireAuth(context, onAuthenticated: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AddressEditScreen(),
                        ),
                      );
                    });
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.add_circle,
                          size: 18, color: AppColors.pickleOrange),
                      const SizedBox(width: 4),
                      Text(
                        'Add New',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.pickleOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!appState.isLoggedIn) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFBD1C4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, color: AppColors.pickleOrange, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Sign in to save and manage your delivery addresses',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => requireAuth(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.pickleOrange,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        'Sign In',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Use Current GPS Location Option
            InkWell(
              onTap: () async {
                await appState.detectAndApplyLocation(forceGps: true);
                if (context.mounted && widget.isSelectMode) {
                  Navigator.of(context).pop();
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: !appState.isManualAddressSelected
                        ? AppColors.leafGreen
                        : AppColors.borderCard,
                    width: !appState.isManualAddressSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.leafGreen.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.my_location_rounded,
                        size: 18,
                        color: AppColors.leafGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Use Current GPS Location',
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (appState.isDetectingLocation) ...[
                                const SizedBox(width: 6),
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.leafGreen,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            'Auto-detects saved address (< 1 km) or current location',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!appState.isManualAddressSelected)
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.leafGreen,
                        size: 18,
                      ),
                  ],
                ),
              ),
            ),

            if (appState.isLoadingAddresses && addresses.isEmpty) ...[
              const SizedBox(height: 60),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: AppColors.pickleOrange),
                    SizedBox(height: 16),
                    Text(
                      'Loading your saved addresses...',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (addresses.isEmpty) ...[
              const SizedBox(height: 48),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.orangeDark.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.location_off_outlined,
                          size: 42,
                          color: AppColors.orangeDark,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'No Saved Addresses Found',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You don\'t have any delivery addresses saved yet. Add your home, office, or relative\'s address to get fresh artisan pickles delivered!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AddressEditScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                        label: Text(
                          'Add Delivery Address',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.pickleOrange,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Address Cards List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: addresses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                final a = addresses[index];
                final isDefault = a.isDefault;

                return InkWell(
                  onTap: widget.isSelectMode
                      ? () {
                          appState.setSelectedAddress(a);
                          Navigator.of(context).pop(a);
                        }
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDefault
                            ? AppColors.leafGreen
                            : AppColors.borderCard,
                        width: isDefault ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                a.label == 'Home'
                                    ? Icons.home_outlined
                                    : (a.label == 'Work'
                                        ? Icons.work_outline
                                        : Icons.location_on_outlined),
                                size: 20,
                                color: AppColors.orangeDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        a.label,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (isDefault) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.successBg,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            'Default',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.leafGreen,
                                            ),
                                          ),
                                        ),
                                      ],
                                      Builder(builder: (_) {
                                        final distance =
                                            appState.getDistanceToAddress(a);
                                        if (distance == null) {
                                          return const SizedBox.shrink();
                                        }
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(left: 6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: distance < 1000
                                                  ? AppColors.leafGreen
                                                      .withValues(alpha: 0.12)
                                                  : AppColors.surfaceContainer,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: distance < 1000
                                                    ? AppColors.leafGreen
                                                        .withValues(alpha: 0.3)
                                                    : AppColors.borderCard,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  distance < 1000
                                                      ? Icons.near_me_rounded
                                                      : Icons.place_outlined,
                                                  size: 10,
                                                  color: distance < 1000
                                                      ? AppColors.leafGreen
                                                      : AppColors
                                                          .textSecondary,
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  distance < 1000
                                                      ? 'Within 1 km (${distance.round()}m)'
                                                      : '${(distance / 1000).toStringAsFixed(1)} km',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: distance < 1000
                                                        ? AppColors.leafGreen
                                                        : AppColors
                                                            .textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                const SizedBox(height: 3),
                                Text(
                                  a.fullAddress,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${a.recipientName} · ${a.phoneNumber}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 10),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 42,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AddressEditScreen(addressToEdit: a),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.edit_outlined,
                                    size: 15, color: AppColors.leafGreen),
                                label: Text(
                                  'Edit',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.leafGreen,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                      color: AppColors.leafGreen, width: 1.5),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!isDefault) ...[
                            Expanded(
                              child: SizedBox(
                                height: 42,
                                child: ElevatedButton(
                                  onPressed: () {
                                    appState.setSelectedAddress(a);
                                    if (widget.isSelectMode) {
                                      Navigator.of(context).pop(a);
                                    } else {
                                      appState.setDefaultAddress(a.id);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              '${a.label} set as default address'),
                                          backgroundColor: AppColors.leafGreen,
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: widget.isSelectMode
                                        ? AppColors.leafGreen
                                        : AppColors.surfaceLow,
                                    foregroundColor: widget.isSelectMode
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    widget.isSelectMode
                                        ? 'Deliver Here'
                                        : 'Set as Default',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: widget.isSelectMode
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 42,
                              height: 42,
                              child: appState.deletingAddressId == a.id
                                  ? const Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.chilliRed,
                                        ),
                                      ),
                                    )
                                  : IconButton(
                                      onPressed: () async {
                                        final res = await appState
                                            .deleteAddressViaApi(a.id);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(res.message ??
                                                  (res.success
                                                      ? 'Address deleted'
                                                      : 'Failed to delete address')),
                                              backgroundColor: res.success
                                                  ? AppColors.textPrimary
                                                  : AppColors.chilliRed,
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18, color: AppColors.chilliRed),
                                      style: IconButton.styleFrom(
                                        backgroundColor: AppColors.surfaceLow,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                            ),
                          ] else ...[
                            Expanded(
                              child: SizedBox(
                                height: 42,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    appState.setDefaultAddress(a.id);
                                    appState.setSelectedAddress(a);
                                    Navigator.of(context).pop(a);
                                  },
                                  icon: const Icon(Icons.check_circle_rounded,
                                      size: 16, color: Colors.white),
                                  label: Text(
                                    'Deliver Here',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.leafGreen,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    alignment: Alignment.center,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
            ),
          ],
        ],
      ),
    ),
    ),
  );
}
}
