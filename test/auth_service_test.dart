import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pickleo/services/auth_service.dart';
import 'package:pickleo/state/app_state.dart';
import 'package:pickleo/models/order.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UserProfile Model & API Schema Tests', () {
    test('Parse UserProfile from live verify OTP response', () {
      final verifyResponseJson = {
        "token": "mock-jwt-token-12345",
        "tokenType": "Bearer",
        "expiresIn": 3600,
        "profile": {
          "userId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
          "phone": "+919876543210",
          "fullName": "Asha Patel",
          "email": "asha@example.com",
          "dateOfBirth": "2026-10-02",
          "gender": "Female",
          "spiceTolerance": "Mild",
          "preferredRegionalStyles": [
            "Andhra"
          ],
          "vegetarianOnly": true,
          "excludeGarlic": true,
          "avatarKey": "avatars/asha.jpg",
          "avatarUrl": "https://s3.amazonaws.com/pickleo/avatars/asha.jpg",
          "createdAt": "2026-10-02T16:35:34.020Z",
          "updatedAt": "2026-10-02T16:35:34.020Z"
        },
        "testMode": true
      };

      final profileJson = verifyResponseJson['profile'] as Map<String, dynamic>;
      final profile = UserProfile.fromJson(profileJson);

      expect(profile.userId, '3fa85f64-5717-4562-b3fc-2c963f66afa6');
      expect(profile.phone, '+919876543210');
      expect(profile.fullName, 'Asha Patel');
      expect(profile.email, 'asha@example.com');
      // Backend creation timestamp 2026-10-02 must be sanitized to empty string
      expect(profile.dateOfBirth, '');
      expect(profile.gender, 'Female');
      expect(profile.spiceTolerance, 'Mild');
      expect(profile.preferredRegionalStyles, ['Andhra']);
      expect(profile.vegetarianOnly, true);
      expect(profile.excludeGarlic, true);
      expect(profile.avatarKey, 'avatars/asha.jpg');
      expect(profile.avatarUrl, 'https://s3.amazonaws.com/pickleo/avatars/asha.jpg');
    });

    test('Parse UserProfile from GET /consumer/profile response', () {
      final getProfileJson = {
        "userId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        "phone": "+919876543210",
        "fullName": "Asha Patel",
        "email": "asha@example.com",
        "dateOfBirth": "2026-10-02",
        "gender": "Female",
        "spiceTolerance": "Mild",
        "preferredRegionalStyles": [
          "Andhra"
        ],
        "vegetarianOnly": true,
        "excludeGarlic": true,
        "avatarKey": "avatars/asha.jpg",
        "avatarUrl": "https://s3.amazonaws.com/pickleo/avatars/asha.jpg",
        "createdAt": "2026-10-02T16:36:10.544Z",
        "updatedAt": "2026-10-02T16:36:10.544Z"
      };

      final profile = UserProfile.fromJson(getProfileJson);

      expect(profile.userId, '3fa85f64-5717-4562-b3fc-2c963f66afa6');
      expect(profile.fullName, 'Asha Patel');
      expect(profile.preferredRegionalStyles.first, 'Andhra');
    });

    test('Parse updated profile from PATCH /consumer/profile response', () {
      final patchResponseJson = {
        "userId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        "phone": "+919876543210",
        "fullName": "Asha Patel",
        "email": "asha@example.com",
        "dateOfBirth": "1992-08-14",
        "gender": "Female",
        "spiceTolerance": "Medium",
        "preferredRegionalStyles": [
          "Andhra",
          "Kerala",
          "Telangana"
        ],
        "vegetarianOnly": true,
        "excludeGarlic": true,
        "avatarKey": "string",
        "avatarUrl": "string",
        "createdAt": "2026-10-02T16:36:59.065Z",
        "updatedAt": "2026-10-02T16:36:59.065Z"
      };

      final profile = UserProfile.fromJson(patchResponseJson);

      expect(profile.fullName, 'Asha Patel');
      expect(profile.dateOfBirth, '1992-08-14');
      expect(profile.spiceTolerance, 'Medium');
      expect(profile.preferredRegionalStyles, ['Andhra', 'Kerala', 'Telangana']);
      expect(profile.vegetarianOnly, true);
      expect(profile.excludeGarlic, true);
    });

    test('Verify avatar upload response structure parsing', () {
      final uploadUrlResponse = {
        "key": "avatars/3fa85f64.jpg",
        "uploadUrl": "https://s3.ap-south-1.amazonaws.com/presigned-put-url",
        "expiresIn": 300
      };

      expect(uploadUrlResponse['key'], 'avatars/3fa85f64.jpg');
      expect(uploadUrlResponse['uploadUrl'], isNotEmpty);
      expect(uploadUrlResponse['expiresIn'], 300);
    });

    test('New user registration profile parses with empty fullName', () {
      final newUserJson = {
        "userId": "fresh-uuid-9999",
        "phone": "+919876543210",
        "createdAt": "2026-10-02T16:35:34.020Z",
        "updatedAt": "2026-10-02T16:35:34.020Z"
      };

      final profile = UserProfile.fromJson(newUserJson);
      expect(profile.fullName, isEmpty);
      expect(profile.phone, '+919876543210');
      expect(profile.userId, 'fresh-uuid-9999');
      expect(profile.spicePoints, 0);
      expect(profile.walletBalance, 0.0);
    });

    test('AppState initializes with no static user data', () {
      final appState = AppState(initialLoggedIn: false);
      expect(appState.userName, isEmpty);
      expect(appState.phoneNumber, isEmpty);
      expect(appState.userEmail, isEmpty);
      expect(appState.dob, isEmpty);
      expect(appState.avatarKey, isNull);
      expect(appState.avatarUrl, isNull);
      expect(appState.walletBalance, 0.0);
      expect(appState.spicePoints, 0);
      expect(appState.isVegetarianOnly, false);
      expect(appState.excludeGarlic, false);
      expect(appState.preferredRegions, isEmpty);
    });

    test('AppState logout resets all user data completely', () {
      final appState = AppState(initialLoggedIn: true);
      appState.logout();
      expect(appState.isLoggedIn, false);
      expect(appState.userName, isEmpty);
      expect(appState.phoneNumber, isEmpty);
      expect(appState.userEmail, isEmpty);
      expect(appState.dob, isEmpty);
      expect(appState.avatarKey, isNull);
      expect(appState.avatarUrl, isNull);
      expect(appState.walletBalance, 0.0);
      expect(appState.spicePoints, 0);
    });

    test('AuthService token lifecycle and 2-minute expiration logic', () async {
      final auth = AuthService();
      await auth.saveTokens(
        token: 'access-token-123',
        refreshToken: 'refresh-token-xyz',
        expiresIn: 3600,
        refreshExpiresIn: 2592000,
      );

      expect(auth.authToken, 'access-token-123');
      expect(auth.refreshToken, 'refresh-token-xyz');
      expect(auth.isRefreshTokenExpired, false);
      expect(auth.isTokenExpiringSoon(thresholdSeconds: 120), false);

      // Simulate token expiring in 60 seconds (less than 2 minutes)
      auth.tokenExpiresAt = DateTime.now().add(const Duration(seconds: 60));
      expect(auth.isTokenExpiringSoon(thresholdSeconds: 120), true);

      // Clean up
      await auth.logout();
      expect(auth.authToken, isNull);
      expect(auth.refreshToken, isNull);
      expect(auth.isTokenExpiringSoon(), true);
    });

    test('Bearer prefix is stripped and token persists cleanly in SharedPreferences', () async {
      final auth = AuthService();
      await auth.saveTokens(
        token: 'Bearer clean-access-token-999',
        refreshToken: 'refresh-token-999',
        expiresIn: 3600,
        refreshExpiresIn: 2592000,
      );

      expect(auth.authToken, 'clean-access-token-999');

      // Test initToken retains the token without wiping
      final restored = await auth.initToken();
      expect(restored, 'clean-access-token-999');
      expect(auth.authToken, 'clean-access-token-999');

      await auth.logout();
    });

    test('DeliveryAddress toLocalJson retains id and fields for offline caching', () {
      final addr = DeliveryAddress(
        id: 'addr-cached-101',
        label: 'Home',
        receiverName: 'Asha Patel',
        phone: '+919876543210',
        flatHouseBuilding: 'Flat 402',
        streetArea: '12th Main Road',
        city: 'Bengaluru',
        postalCode: '560038',
        isDefault: true,
      );

      final localMap = addr.toLocalJson();
      expect(localMap['id'], 'addr-cached-101');
      expect(localMap['label'], 'Home');
      expect(localMap['receiverName'], 'Asha Patel');
      expect(localMap['isDefault'], true);

      final reconstructed = DeliveryAddress.fromJson(localMap);
      expect(reconstructed.id, 'addr-cached-101');
      expect(reconstructed.receiverName, 'Asha Patel');
      expect(reconstructed.city, 'Bengaluru');
    });
  });

  group('ApiResponse & Network Error Sanitization Tests', () {
    test('Sanitizes SocketException and Failed host lookup into friendly message', () {
      final res = ApiResponse.error(
        'Network error: SocketException: Failed host lookup: \'pickleo.co.in\' (OS Error: No address associated with hostname, errno = 7)',
      );
      expect(res.message, 'No internet connection. Please check your network and try again.');
    });

    test('Sanitizes TimeoutException into friendly message', () {
      final res = ApiResponse.error(
        'Network error: TimeoutException after 0:00:15.000000: Future not completed',
      );
      expect(res.message, 'Connection timed out. Please check your network and try again.');
    });

    test('Sanitizes ClientException into friendly message', () {
      final res = ApiResponse.error(
        'Network error: ClientException: Connection reset by peer',
      );
      expect(res.message, contains('Please check your network and try again.'));
    });

    test('Extracts error or message from JSON responses', () {
      final res1 = ApiResponse.error('{"error": "Only 0 units are currently available."}');
      expect(res1.message, 'Only 0 units are currently available.');

      final res2 = ApiResponse.error('{"message": "Invalid OTP provided"}');
      expect(res2.message, 'Invalid OTP provided');
    });

    test('Preserves plain user-facing error messages', () {
      final res = ApiResponse.error('Product not found in this region');
      expect(res.message, 'Product not found in this region');
    });
  });
}
