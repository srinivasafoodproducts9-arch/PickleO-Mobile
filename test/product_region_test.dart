import 'package:flutter_test/flutter_test.dart';
import 'package:pickleo/models/product_region.dart';

void main() {
  group('ProductRegion Model & API Schema Tests', () {
    test('Parses ProductRegion correctly from GET /product-regions response schema', () {
      final json = {
        'id': 'reg_andhra_001',
        'name': 'Andhra',
        'legacy': true,
        'description': 'Avakaya, Gongura, Pachadi',
        'imageKey': 'regions/andhra.jpg',
        'imageUrl': 'https://example.com/regions/andhra.jpg',
      };

      final region = ProductRegion.fromJson(json);

      expect(region.id, 'reg_andhra_001');
      expect(region.name, 'Andhra');
      expect(region.legacy, isTrue);
      expect(region.description, 'Avakaya, Gongura, Pachadi');
      expect(region.imageKey, 'regions/andhra.jpg');
      expect(region.imageUrl, 'https://example.com/regions/andhra.jpg');
      expect(region.hasValidImage, isTrue);
      expect(region.icon, '🌶️');
      expect(region.sub, 'Avakaya, Gongura, Pachadi');
    });

    test('Handles boolean and string legacy flags correctly', () {
      final boolRegion = ProductRegion.fromJson({
        'id': '1',
        'name': 'Kerala',
        'legacy': true,
      });
      expect(boolRegion.legacy, isTrue);

      final strRegion = ProductRegion.fromJson({
        'id': '2',
        'name': 'Telangana',
        'legacy': 'true',
      });
      expect(strRegion.legacy, isTrue);

      final falseRegion = ProductRegion.fromJson({
        'id': '3',
        'name': 'Tamil Nadu',
        'legacy': false,
      });
      expect(falseRegion.legacy, isFalse);
    });

    test('Handles valid vs invalid image URLs correctly', () {
      final valid = ProductRegion(
        id: '1',
        name: 'Andhra',
        imageUrl: 'https://cdn.example.com/andhra.png',
      );
      expect(valid.hasValidImage, isTrue);

      final mockString = ProductRegion(
        id: '2',
        name: 'Kerala',
        imageUrl: 'string',
      );
      expect(mockString.hasValidImage, isFalse);

      final empty = ProductRegion(
        id: '3',
        name: 'Gujarat',
        imageUrl: '',
      );
      expect(empty.hasValidImage, isFalse);

      final nullUrl = ProductRegion(
        id: '4',
        name: 'Rajasthan',
        imageUrl: null,
      );
      expect(nullUrl.hasValidImage, isFalse);
    });

    test('Serializes to JSON and deserializes for offline caching', () {
      final region = ProductRegion(
        id: 'reg_kerala_002',
        name: 'Kerala',
        legacy: true,
        description: 'Coconut, Kadumanga, Tender Mango',
        imageKey: 'regions/kerala.jpg',
        imageUrl: 'https://example.com/kerala.jpg',
      );

      final json = region.toJson();
      final restored = ProductRegion.fromJson(json);

      expect(restored.id, region.id);
      expect(restored.name, region.name);
      expect(restored.legacy, region.legacy);
      expect(restored.description, region.description);
      expect(restored.imageKey, region.imageKey);
      expect(restored.imageUrl, region.imageUrl);
      expect(restored.icon, '🥥');
    });

    test('Parses items array correctly from GET /product-regions response envelope', () {
      final apiResponse = {
        'items': [
          {
            'id': '1',
            'name': 'Andhra',
            'legacy': true,
            'description': 'Avakaya, Gongura',
            'imageKey': 'string',
            'imageUrl': 'string',
          },
          {
            'id': '2',
            'name': 'Kerala',
            'legacy': true,
            'description': 'Coconut, Kadumanga',
            'imageKey': 'string',
            'imageUrl': 'string',
          },
          {
            'id': '3',
            'name': 'Telangana',
            'legacy': true,
            'description': 'Pachadi, Podi',
            'imageKey': 'string',
            'imageUrl': 'string',
          },
          {
            'id': '4',
            'name': 'Tamil Nadu',
            'legacy': false,
            'description': 'Murukku, Podi',
            'imageKey': 'string',
            'imageUrl': 'string',
          },
        ]
      };

      final items = (apiResponse['items'] as List)
          .map((m) => ProductRegion.fromJson(m as Map<String, dynamic>))
          .toList();

      expect(items.length, 4);
      expect(items[0].name, 'Andhra');
      expect(items[1].name, 'Kerala');
      expect(items[2].name, 'Telangana');
      expect(items[3].name, 'Tamil Nadu');
    });
  });
}
