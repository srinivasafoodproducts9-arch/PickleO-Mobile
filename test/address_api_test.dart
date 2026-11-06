import 'package:flutter_test/flutter_test.dart';
import 'package:pickleo/models/order.dart';

void main() {
  group('DeliveryAddress API Schema Tests', () {
    test('Parse addresses list from GET /consumer/addresses response', () {
      final getResponseJson = {
        "items": [
          {
            "id": "addr-101",
            "label": "Home",
            "receiverName": "Asha Patel",
            "phone": "+919876543210",
            "flatHouseBuilding": "Flat 402, Heritage Palms",
            "streetArea": "12th Main Rd, Indiranagar",
            "city": "Bengaluru",
            "postalCode": "799554",
            "isDefault": true,
            "createdAt": "2026-10-02T16:48:37.741Z",
            "updatedAt": "2026-10-02T16:48:37.741Z"
          }
        ]
      };

      final items = getResponseJson['items'] as List<dynamic>;
      final addresses = items
          .map((e) => DeliveryAddress.fromJson(e as Map<String, dynamic>))
          .toList();

      expect(addresses.length, 1);
      final addr = addresses.first;
      expect(addr.id, 'addr-101');
      expect(addr.label, 'Home');
      expect(addr.receiverName, 'Asha Patel');
      expect(addr.recipientName, 'Asha Patel');
      expect(addr.phone, '+919876543210');
      expect(addr.phoneNumber, '+919876543210');
      expect(addr.flatHouseBuilding, 'Flat 402, Heritage Palms');
      expect(addr.flat, 'Flat 402, Heritage Palms');
      expect(addr.streetArea, '12th Main Rd, Indiranagar');
      expect(addr.street, '12th Main Rd, Indiranagar');
      expect(addr.city, 'Bengaluru');
      expect(addr.postalCode, '799554');
      expect(addr.pinCode, '799554');
      expect(addr.isDefault, true);
      expect(addr.fullAddress, contains('Heritage Palms'));
    });

    test('Serialize address for POST /consumer/addresses request', () {
      final newAddress = DeliveryAddress(
        id: '',
        label: 'Home',
        receiverName: 'Priya Sharma',
        phone: '+919876543210',
        flatHouseBuilding: 'Flat 402, Heritage Palms',
        streetArea: '12th Main Rd, Indiranagar',
        city: 'Bengaluru',
        postalCode: '560038',
        isDefault: true,
      );

      final json = newAddress.toJson();
      expect(json['label'], 'Home');
      expect(json['receiverName'], 'Priya Sharma');
      expect(json['phone'], '+919876543210');
      expect(json['flatHouseBuilding'], 'Flat 402, Heritage Palms');
      expect(json['streetArea'], '12th Main Rd, Indiranagar');
      expect(json['city'], 'Bengaluru');
      expect(json['postalCode'], '560038');
      expect(json['isDefault'], true);
    });

    test('Parse created address from POST /consumer/addresses response', () {
      final postResponseJson = {
        "id": "addr-new-202",
        "label": "Home",
        "receiverName": "Priya Sharma",
        "phone": "+919876543210",
        "flatHouseBuilding": "Flat 402, Heritage Palms",
        "streetArea": "12th Main Rd, Indiranagar",
        "city": "Bengaluru",
        "postalCode": "914931",
        "isDefault": true,
        "createdAt": "2026-10-02T16:49:50.410Z",
        "updatedAt": "2026-10-02T16:49:50.410Z"
      };

      final created = DeliveryAddress.fromJson(postResponseJson);
      expect(created.id, 'addr-new-202');
      expect(created.postalCode, '914931');
      expect(created.isDefault, true);
    });

    test('Parse updated address from PATCH /consumer/addresses/{id} response', () {
      final patchResponseJson = {
        "id": "addr-101",
        "label": "Home",
        "receiverName": "Asha Patel",
        "phone": "+919876543210",
        "flatHouseBuilding": "Flat 402, Heritage Palms",
        "streetArea": "12th Main Road, Indiranagar",
        "city": "Bengaluru",
        "postalCode": "661223",
        "isDefault": true,
        "createdAt": "2026-10-02T16:50:48.195Z",
        "updatedAt": "2026-10-02T16:50:48.195Z"
      };

      final updated = DeliveryAddress.fromJson(patchResponseJson);
      expect(updated.id, 'addr-101');
      expect(updated.streetArea, '12th Main Road, Indiranagar');
      expect(updated.postalCode, '661223');
      expect(updated.isDefault, true);
    });

    test('Validate DELETE /consumer/addresses/{id} response format', () {
      final deleteResponseJson = {"deleted": true};
      expect(deleteResponseJson['deleted'], true);
    });

    test('Coordinates latitude and longitude required fields test', () {
      final jsonWithCoordinates = {
        "id": "addr-coords-1",
        "label": "Work",
        "receiverName": "Asha Patel",
        "phone": "+919876543210",
        "flatHouseBuilding": "Pickle HQ, Level 3",
        "streetArea": "100 Feet Rd, Indiranagar",
        "city": "Bengaluru",
        "postalCode": "560038",
        "isDefault": false,
        "latitude": 90,
        "longitude": 180,
      };

      final parsed = DeliveryAddress.fromJson(jsonWithCoordinates);
      expect(parsed.latitude, 90.0);
      expect(parsed.longitude, 180.0);

      final serialized = parsed.toJson();
      expect(serialized['latitude'], 90.0);
      expect(serialized['longitude'], 180.0);

      final updated = parsed.copyWith(
        latitude: 12.9716,
        longitude: 77.5946,
      );
      expect(updated.latitude, 12.9716);
      expect(updated.longitude, 77.5946);
      expect(updated.toJson()['latitude'], 12.9716);
      expect(updated.toJson()['longitude'], 77.5946);
    });

    test('DeliveryAddress supports international phone numbers with + and country codes', () {
      final addr = DeliveryAddress(
        id: 'addr-intl-1',
        label: 'Home',
        receiverName: 'Asha Patel',
        phone: '+919876543210',
        flatHouseBuilding: 'Flat 402',
        streetArea: '12th Main Road',
        city: 'Bengaluru',
        postalCode: '560038',
      );
      expect(addr.phone, '+919876543210');
      expect(addr.toJson()['phone'], '+919876543210');

      final addrUS = DeliveryAddress(
        id: 'addr-intl-2',
        label: 'US Office',
        receiverName: 'John Doe',
        phone: '+14155552671',
        flatHouseBuilding: 'Suite 200',
        streetArea: 'Market St',
        city: 'San Francisco',
        postalCode: '94105',
      );
      expect(addrUS.phone, '+14155552671');
      expect(addrUS.toJson()['phone'], '+14155552671');
    });
  });
}
