import 'package:flutter_test/flutter_test.dart';
import 'package:pickleo/models/category.dart';

void main() {
  group('CategoryItem Model & API Schema Tests', () {
    test('Parses CategoryItem correctly from GET /categories response schema', () {
      final json = {
        'id': 'cat_mango_123',
        'name': 'Pickles & Achaar',
        'imageKey': 'categories/pickles.jpg',
        'imageUrl': 'https://example.com/images/pickles.jpg',
        'createdAt': '2026-10-04T00:13:17.107Z',
      };

      final category = CategoryItem.fromJson(json);

      expect(category.id, 'cat_mango_123');
      expect(category.name, 'Pickles & Achaar');
      expect(category.imageKey, 'categories/pickles.jpg');
      expect(category.imageUrl, 'https://example.com/images/pickles.jpg');
      expect(category.createdAt, '2026-10-04T00:13:17.107Z');
      expect(category.hasValidImage, isTrue);
      expect(category.chip, 'All Pickles');
      expect(category.badge, '');
    });

    test('Parses new dynamic category without curated metadata gracefully', () {
      final json = {
        'id': 'cat_special_001',
        'name': 'Herbal Oils & Ghee',
        'imageKey': 'categories/ghee.png',
        'imageUrl': 'https://example.com/images/ghee.png',
        'createdAt': '2026-10-04T00:13:17.107Z',
      };

      final category = CategoryItem.fromJson(json);

      expect(category.id, 'cat_special_001');
      expect(category.name, 'Herbal Oils & Ghee');
      expect(category.hasValidImage, isTrue);
      expect(category.chip, 'Herbal Oils & Ghee');
      expect(category.count, 'Fresh Batches');
    });

    test('Correctly identifies valid vs invalid image URLs', () {
      final validItem = CategoryItem(
        id: '1',
        name: 'Pickles',
        chip: 'All Pickles',
        imageUrl: 'https://cdn.example.com/pic.png',
      );
      expect(validItem.hasValidImage, isTrue);

      final httpItem = CategoryItem(
        id: '2',
        name: 'Chutneys',
        chip: 'Chutneys',
        imageUrl: 'http://cdn.example.com/pic.png',
      );
      expect(httpItem.hasValidImage, isTrue);

      final emptyItem = CategoryItem(
        id: '3',
        name: 'Podis',
        chip: 'Podis',
        imageUrl: '',
      );
      expect(emptyItem.hasValidImage, isFalse);

      final mockStringItem = CategoryItem(
        id: '4',
        name: 'Sweets',
        chip: 'Sweets',
        imageUrl: 'string',
      );
      expect(mockStringItem.hasValidImage, isFalse);

      final nullItem = CategoryItem(
        id: '5',
        name: 'Millets',
        chip: 'Millets',
        imageUrl: null,
      );
      expect(nullItem.hasValidImage, isFalse);
    });

    test('Serializes to JSON and deserializes for SharedPreferences caching', () {
      final item = CategoryItem(
        id: 'cat_01',
        name: 'Snacks & Murukku',
        chip: 'Snacks',
        imageKey: 'keys/murukku.jpg',
        imageUrl: 'https://example.com/murukku.jpg',
        createdAt: '2026-10-04T00:13:17.107Z',
        count: '16 batches',
        sub: 'Hand-pressed, fried in small batches',
        badge: 'Crispy',
      );

      final json = item.toJson();
      final restored = CategoryItem.fromJson(json);

      expect(restored.id, item.id);
      expect(restored.name, item.name);
      expect(restored.chip, item.chip);
      expect(restored.imageKey, item.imageKey);
      expect(restored.imageUrl, item.imageUrl);
      expect(restored.createdAt, item.createdAt);
      expect(restored.badge, 'Crispy');
    });

    test('Parses complete 10-item UAT categories API response correctly', () {
      final uatResponse = {
        "items": [
          {
            "entityType": "CATEGORY",
            "imageKey": "categories/2026-10-03/3252dbb5-1937-4bad-a59f-2f236b69553c.png",
            "createdAt": "2026-10-03T14:06:39.566Z",
            "id": "chutneys",
            "name": "Chutneys",
            "createdBy": "srinivasafoodproducts9@gmail.com",
            "imageUrl": "https://pickleo-uat-productmediabucket-crczhrxw5sj3.s3.ap-south-1.amazonaws.com/categories/2026-10-03/3252dbb5-1937-4bad-a59f-2f236b69553c.png?X-Amz-Algorithm=AWS4-HMAC-SHA256"
          },
          {
            "entityType": "CATEGORY",
            "imageKey": "categories/2026-10-03/3d9848e6-d0cc-4417-8e13-8430d7d4a5f0.png",
            "createdAt": "2026-10-03T14:10:27.466Z",
            "id": "combos & gifts",
            "name": "Combos & Gifts",
            "createdBy": "srinivasafoodproducts9@gmail.com",
            "imageUrl": "https://pickleo-uat-productmediabucket-crczhrxw5sj3.s3.ap-south-1.amazonaws.com/categories/2026-10-03/3d9848e6-d0cc-4417-8e13-8430d7d4a5f0.png?X-Amz-Algorithm=AWS4-HMAC-SHA256"
          },
          {
            "entityType": "CATEGORY",
            "imageKey": "",
            "createdAt": "2026-10-03T14:08:48.278Z",
            "id": "millet foods",
            "name": "Millet Foods",
            "createdBy": "srinivasafoodproducts9@gmail.com"
          },
          {
            "entityType": "CATEGORY",
            "imageKey": "categories/2026-10-03/8ded6178-8b68-4619-8496-c150180702b2.png",
            "createdAt": "2026-10-03T14:09:41.188Z",
            "id": "millets foods",
            "name": "Millets Foods",
            "createdBy": "srinivasafoodproducts9@gmail.com",
            "imageUrl": "https://pickleo-uat-productmediabucket-crczhrxw5sj3.s3.ap-south-1.amazonaws.com/categories/2026-10-03/8ded6178-8b68-4619-8496-c150180702b2.png?X-Amz-Algorithm=AWS4-HMAC-SHA256"
          },
          {
            "entityType": "CATEGORY",
            "imageKey": "categories/2026-10-03/acdc557c-8bf9-4ffe-a1e0-5f4f13d57b2e.png",
            "createdAt": "2026-10-03T14:06:17.464Z",
            "id": "pickle & achaar",
            "createdBy": "srinivasafoodproducts9@gmail.com",
            "name": "Pickle & Achaar",
            "imageUrl": "https://pickleo-uat-productmediabucket-crczhrxw5sj3.s3.ap-south-1.amazonaws.com/categories/2026-10-03/acdc557c-8bf9-4ffe-a1e0-5f4f13d57b2e.png?X-Amz-Algorithm=AWS4-HMAC-SHA256"
          },
          {
            "entityType": "CATEGORY",
            "imageKey": "categories/2026-10-03/ed779b79-b8a8-42ed-9f22-7a6b7ee56cbc.png",
            "createdAt": "2026-10-03T14:07:16.307Z",
            "id": "podis & powders",
            "name": "Podis & Powders",
            "createdBy": "srinivasafoodproducts9@gmail.com",
            "imageUrl": "https://pickleo-uat-productmediabucket-crczhrxw5sj3.s3.ap-south-1.amazonaws.com/categories/2026-10-03/ed779b79-b8a8-42ed-9f22-7a6b7ee56cbc.png?X-Amz-Algorithm=AWS4-HMAC-SHA256"
          },
          {
            "entityType": "CATEGORY",
            "imageKey": "categories/2026-10-03/37d745a7-7bba-4953-9b33-e891317a4949.png",
            "createdAt": "2026-10-03T14:07:56.891Z",
            "id": "prices & masala",
            "createdBy": "srinivasafoodproducts9@gmail.com",
            "name": "Prices & Masala",
            "imageUrl": "https://pickleo-uat-productmediabucket-crczhrxw5sj3.s3.ap-south-1.amazonaws.com/categories/2026-10-03/37d745a7-7bba-4953-9b33-e891317a4949.png?X-Amz-Algorithm=AWS4-HMAC-SHA256"
          },
          {
            "entityType": "CATEGORY",
            "imageKey": "categories/2026-10-03/7654da80-4814-457c-98d5-9b00065e946e.png",
            "createdAt": "2026-10-03T14:10:06.601Z",
            "id": "ready to eat",
            "name": "Ready to Eat",
            "createdBy": "srinivasafoodproducts9@gmail.com",
            "imageUrl": "https://pickleo-uat-productmediabucket-crczhrxw5sj3.s3.ap-south-1.amazonaws.com/categories/2026-10-03/7654da80-4814-457c-98d5-9b00065e946e.png?X-Amz-Algorithm=AWS4-HMAC-SHA256"
          },
          {
            "entityType": "CATEGORY",
            "imageKey": "categories/2026-10-03/5d313c41-0cbe-4f82-b942-95b597b54424.png",
            "createdAt": "2026-10-03T14:07:36.077Z",
            "id": "snacks & murukulu",
            "name": "Snacks & Murukulu",
            "createdBy": "srinivasafoodproducts9@gmail.com",
            "imageUrl": "https://pickleo-uat-productmediabucket-crczhrxw5sj3.s3.ap-south-1.amazonaws.com/categories/2026-10-03/5d313c41-0cbe-4f82-b942-95b597b54424.png?X-Amz-Algorithm=AWS4-HMAC-SHA256"
          },
          {
            "entityType": "CATEGORY",
            "imageKey": "categories/2026-10-03/f1a5339b-ebb1-446e-aaa2-02ce34423192.png",
            "createdAt": "2026-10-03T14:08:31.521Z",
            "id": "sweets",
            "createdBy": "srinivasafoodproducts9@gmail.com",
            "name": "Sweets",
            "imageUrl": "https://pickleo-uat-productmediabucket-crczhrxw5sj3.s3.ap-south-1.amazonaws.com/categories/2026-10-03/f1a5339b-ebb1-446e-aaa2-02ce34423192.png?X-Amz-Algorithm=AWS4-HMAC-SHA256"
          }
        ]
      };

      final items = (uatResponse['items'] as List)
          .map((m) => CategoryItem.fromJson(m as Map<String, dynamic>))
          .toList();

      expect(items.length, 10);

      // Verify all items have entityType and createdBy
      for (final cat in items) {
        expect(cat.entityType, 'CATEGORY');
        expect(cat.createdBy, 'srinivasafoodproducts9@gmail.com');
      }

      // Verify Millet Foods (imageKey is empty string, no imageUrl)
      final milletFoods = items.firstWhere((c) => c.id == 'millet foods');
      expect(milletFoods.hasValidImage, isFalse);
      expect(milletFoods.resolvedImageUrl, isNull);
      expect(milletFoods.assetImage, 'assets/images/cat2-millets.png');

      // Verify Prices & Masala matches metadata
      final masala = items.firstWhere((c) => c.id == 'prices & masala');
      expect(masala.hasValidImage, isTrue);
      expect(masala.assetImage, 'assets/images/cat2-spices.png');

      // Verify Snacks & Murukulu matches metadata
      final snacks = items.firstWhere((c) => c.id == 'snacks & murukulu');
      expect(snacks.hasValidImage, isTrue);
      expect(snacks.assetImage, 'assets/images/cat2-snacks.png');
    });
  });
}
