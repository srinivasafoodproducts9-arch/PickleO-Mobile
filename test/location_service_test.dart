import 'package:flutter_test/flutter_test.dart';
import 'package:pickleo/services/location_service.dart';

void main() {
  group('LocationService Address Sanitization & Formatting', () {
    test('cleanAddressLine removes Asia and India prefixes', () {
      expect(LocationService.cleanAddressLine('Asia, Narasaraopet'), 'Narasaraopet');
      expect(LocationService.cleanAddressLine('Asia, Balayyanagar, Narasaraopet'), 'Balayyanagar, Narasaraopet');
      expect(LocationService.cleanAddressLine('India, Main Road, Balayyanagar'), 'Main Road, Balayyanagar');
      expect(LocationService.cleanAddressLine('Asia / Kolkata, Street 5'), 'Street 5');
    });

    test('cleanAddressLine strips standalone continent or country', () {
      expect(LocationService.cleanAddressLine('Asia'), '');
      expect(LocationService.cleanAddressLine('India'), '');
      expect(LocationService.cleanAddressLine('Asia, India'), '');
    });

    test('cleanAddressLine preserves full rich address line 1', () {
      expect(
        LocationService.cleanAddressLine('Balayyanagar, Narasaraopeta Urban'),
        'Balayyanagar, Narasaraopeta Urban',
      );
      expect(
        LocationService.cleanAddressLine('D.No 4-12, Main Bazaar, Balayyanagar'),
        'D.No 4-12, Main Bazaar, Balayyanagar',
      );
    });

    test('cleanAddressLine deduplicates tokens and filters pincodes', () {
      expect(
        LocationService.cleanAddressLine('Balayyanagar, Balayyanagar, 522600'),
        'Balayyanagar',
      );
    });

    test('searchPlaces returns empty list for empty or whitespace query', () async {
      final resEmpty = await LocationService().searchPlaces('');
      final resWhitespace = await LocationService().searchPlaces('   ');
      expect(resEmpty, isEmpty);
      expect(resWhitespace, isEmpty);
    });
  });
}
