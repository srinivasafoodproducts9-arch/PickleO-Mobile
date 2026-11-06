import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:upgrader/upgrader.dart';

/// Customized PickleO branded messages for the App Store & Play Store update dialog
class PickleOUpgraderMessages extends UpgraderMessages {
  @override
  String? message(UpgraderMessage messageKey) {
    switch (messageKey) {
      case UpgraderMessage.title:
        return 'Update PickleO?';
      case UpgraderMessage.body:
        return 'A new version of PickleO is available with latest improvements and fresh flavors. Please update for the best experience!';
      case UpgraderMessage.prompt:
        return 'Would you like to update now?';
      case UpgraderMessage.buttonTitleUpdate:
        return 'UPDATE NOW';
      case UpgraderMessage.buttonTitleLater:
        return 'LATER';
      case UpgraderMessage.buttonTitleIgnore:
        return 'IGNORE';
      case UpgraderMessage.releaseNotes:
        return "What's New:";
    }
  }
}

/// Central configuration for auto-update alerts on Android & iOS
class AppUpgraderConfig {
  static final Upgrader shared = Upgrader(
    debugLogging: kDebugMode,
    durationUntilAlertAgain: const Duration(days: 1),
    messages: PickleOUpgraderMessages(),
  );

  /// Direct link to the Play Store or App Store page
  static Future<void> openStore() async {
    Uri? storeUri;

    if (!kIsWeb && Platform.isAndroid) {
      storeUri = Uri.parse(
          'https://play.google.com/store/apps/details?id=com.pickleo.app');
    } else if (!kIsWeb && Platform.isIOS) {
      // Directs to Apple App Store
      storeUri = Uri.parse('https://apps.apple.com/app/pickleo');
    } else {
      storeUri = Uri.parse('https://pickleo.co.in');
    }

    try {
      if (await canLaunchUrl(storeUri)) {
        await launchUrl(storeUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch store URL: $e');
    }
  }
}

