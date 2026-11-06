import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pickleo/models/product_tag.dart';
import 'package:pickleo/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ProductTag Model & API Schema Tests', () {
    test('Parses ProductTag correctly from GET /product-tags response schema', () {
      final json = {
        'id': 'tag_spicy_001',
        'name': 'Spicy',
        'slug': 'spicy',
        'description': 'Traditional fiery Andhra spice',
        'icon': '🌶️',
        'imageKey': 'tags/spicy.png',
        'imageUrl': 'https://example.com/tags/spicy.png',
        'sortOrder': 1,
      };

      final tag = ProductTag.fromJson(json);

      expect(tag.id, 'tag_spicy_001');
      expect(tag.name, 'Spicy');
      expect(tag.slug, 'spicy');
      expect(tag.description, 'Traditional fiery Andhra spice');
      expect(tag.icon, '🌶️');
      expect(tag.imageKey, 'tags/spicy.png');
      expect(tag.imageUrl, 'https://example.com/tags/spicy.png');
      expect(tag.hasValidImage, isTrue);
      expect(tag.sortOrder, 1);
    });

    test('Handles alternative key names (title, label, tag) flexibly', () {
      final t1 = ProductTag.fromJson({'id': '1', 'title': 'Tangy'});
      expect(t1.name, 'Tangy');

      final t2 = ProductTag.fromJson({'tagId': '2', 'label': 'Mild'});
      expect(t2.id, '2');
      expect(t2.name, 'Mild');

      final t3 = ProductTag.fromJson({'tag_id': '3', 'tag_name': 'No Preservatives'});
      expect(t3.id, '3');
      expect(t3.name, 'No Preservatives');
    });

    test('Serializes to JSON and deserializes correctly for offline caching', () {
      const tag = ProductTag(
        id: 'tag_oil_free',
        name: 'Oil-Free',
        slug: 'oil-free',
        sortOrder: 5,
      );

      final json = tag.toJson();
      final restored = ProductTag.fromJson(json);

      expect(restored.id, tag.id);
      expect(restored.name, tag.name);
      expect(restored.slug, tag.slug);
      expect(restored.sortOrder, tag.sortOrder);
    });

    test('Provides fallback default tags when API returns empty', () {
      expect(ProductTag.defaultTags, isNotEmpty);
      expect(ProductTag.defaultTags.map((t) => t.name), contains('Spicy'));
      expect(ProductTag.defaultTags.map((t) => t.name), contains('Tangy'));
    });

    test('AppState exposes empty productTags when API has not loaded or failed', () async {
      final appState = AppState();
      expect(appState.productTags, isEmpty);
      expect(appState.hasLoadedProductTags, isFalse);
    });
  });
}
