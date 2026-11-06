import 'package:flutter_test/flutter_test.dart';
import 'package:pickleo/models/banner.dart';

void main() {
  group('HomeBanner Model & Business Logic Tests', () {
    test('Correctly parses HomeBanner from JSON', () {
      final json = {
        'id': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
        'title': 'Grandma Mango Pickle',
        'mediaType': 'video',
        'mediaKey': 'banners/video1.mp4',
        'contentType': 'video/mp4',
        'mediaUrl': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        'status': 'Active',
        'sortOrder': 10,
        'createdAt': '2026-10-04T00:10:37.656Z',
        'updatedAt': '2026-10-04T00:10:37.659Z',
      };

      final banner = HomeBanner.fromJson(json);

      expect(banner.id, '3fa85f64-5717-4562-b3fc-2c963f66afa6');
      expect(banner.title, 'Grandma Mango Pickle');
      expect(banner.mediaType, 'video');
      expect(banner.isVideo, isTrue);
      expect(banner.isImage, isFalse);
      expect(banner.status, 'Active');
      expect(banner.isActive, isTrue);
      expect(banner.sortOrder, 10);
      expect(banner.mediaUrl, contains('.mp4'));
    });

    test('Filters out non-Active banners', () {
      final List<HomeBanner> rawList = [
        HomeBanner(
          id: '1',
          title: 'Active Banner',
          mediaType: 'image',
          mediaUrl: 'https://example.com/img1.png',
          status: 'Active',
          sortOrder: 0,
        ),
        HomeBanner(
          id: '2',
          title: 'Inactive Banner',
          mediaType: 'image',
          mediaUrl: 'https://example.com/img2.png',
          status: 'Inactive',
          sortOrder: 0,
        ),
        HomeBanner(
          id: '3',
          title: 'Draft Banner',
          mediaType: 'video',
          mediaUrl: 'https://example.com/vid.mp4',
          status: 'Draft',
          sortOrder: 0,
        ),
      ];

      final processed = HomeBanner.processBanners(rawList);

      expect(processed.length, 1);
      expect(processed.first.id, '1');
      expect(processed.first.title, 'Active Banner');
    });

    test('Preserves list order when all sortOrder are 0', () {
      final List<HomeBanner> rawList = [
        HomeBanner(
          id: 'banner_c',
          title: 'Banner C',
          mediaType: 'image',
          mediaUrl: 'https://example.com/c.png',
          status: 'Active',
          sortOrder: 0,
        ),
        HomeBanner(
          id: 'banner_a',
          title: 'Banner A',
          mediaType: 'video',
          mediaUrl: 'https://example.com/a.mp4',
          status: 'Active',
          sortOrder: 0,
        ),
        HomeBanner(
          id: 'banner_b',
          title: 'Banner B',
          mediaType: 'image',
          mediaUrl: 'https://example.com/b.png',
          status: 'active',
          sortOrder: 0,
        ),
      ];

      final processed = HomeBanner.processBanners(rawList);

      expect(processed.length, 3);
      expect(processed[0].id, 'banner_c');
      expect(processed[1].id, 'banner_a');
      expect(processed[2].id, 'banner_b');
    });

    test('Sorts ascending by sortOrder when not all sortOrder are 0', () {
      final List<HomeBanner> rawList = [
        HomeBanner(
          id: 'banner_30',
          title: 'Order 30',
          mediaType: 'image',
          mediaUrl: 'https://example.com/30.png',
          status: 'Active',
          sortOrder: 30,
        ),
        HomeBanner(
          id: 'banner_5',
          title: 'Order 5',
          mediaType: 'image',
          mediaUrl: 'https://example.com/5.png',
          status: 'Active',
          sortOrder: 5,
        ),
        HomeBanner(
          id: 'banner_15',
          title: 'Order 15',
          mediaType: 'video',
          mediaUrl: 'https://example.com/15.mp4',
          status: 'Active',
          sortOrder: 15,
        ),
      ];

      final processed = HomeBanner.processBanners(rawList);

      expect(processed.length, 3);
      expect(processed[0].id, 'banner_5');
      expect(processed[1].id, 'banner_15');
      expect(processed[2].id, 'banner_30');
    });

    test('Handles video and image media types correctly', () {
      final videoBanner = HomeBanner(
        id: 'v1',
        title: 'Making Mango Pickle',
        mediaType: 'video',
        mediaUrl: 'https://example.com/video.mp4',
        status: 'Active',
        sortOrder: 1,
      );

      final imageBanner = HomeBanner(
        id: 'i1',
        title: 'Heritage Spices',
        mediaType: 'image',
        mediaUrl: 'https://example.com/spices.jpg',
        status: 'Active',
        sortOrder: 2,
      );

      expect(videoBanner.isVideo, isTrue);
      expect(videoBanner.isImage, isFalse);

      expect(imageBanner.isVideo, isFalse);
      expect(imageBanner.isImage, isTrue);
    });

    test('Parses items from new GET /consumer/banners response structure', () {
      final jsonResponse = {
        "items": [
          {
            "id": "banner-id",
            "title": "Banner title",
            "mediaType": "image",
            "mediaUrl": "https://example.com/signed-media-url",
            "status": "Active",
            "sortOrder": 0
          }
        ]
      };

      final items = (jsonResponse['items'] as List)
          .map((m) => HomeBanner.fromJson(m as Map<String, dynamic>))
          .toList();

      expect(items.length, 1);
      final b = items.first;
      expect(b.id, 'banner-id');
      expect(b.title, 'Banner title');
      expect(b.mediaType, 'image');
      expect(b.mediaUrl, 'https://example.com/signed-media-url');
      expect(b.status, 'Active');
      expect(b.isActive, isTrue);
      expect(b.isImage, isTrue);
      expect(b.isVideo, isFalse);
      expect(b.sortOrder, 0);
    });

    test('Parses full 6-item UAT banner response and preserves sort ordering', () {
      final fullResponse = {
        "items": [
          {
            "entityType": "BANNER",
            "mediaType": "image",
            "status": "Active",
            "createdAt": "2026-10-03T14:18:54.819Z",
            "contentType": "image/png",
            "createdBy": "srinivasafoodproducts9@gmail.com",
            "mediaKey": "banners/images/2026-10-03/cb63dcdd-8923-40c1-8a47-4f4444b23363.png",
            "updatedAt": "2026-10-03T14:18:54.819Z",
            "id": "13739dcb-6bb6-46bc-b109-2cb44b07b3e6",
            "sortOrder": 0,
            "title": "Nawabi flavors, spicy pickles & timeless Deccan favorites.",
            "mediaUrl": "https://pickleo-uat-productmediabucket-crczhrxw5sj3.s3.ap-south-1.amazonaws.com/banners/images/2026-10-03/cb63dcdd-8923-40c1-8a47-4f4444b23363.png?X-Amz-Algorithm=AWS4-HMAC-SHA256"
          },
          {
            "entityType": "BANNER",
            "mediaType": "image",
            "status": "Active",
            "createdAt": "2026-10-03T14:15:58.867Z",
            "createdBy": "srinivasafoodproducts9@gmail.com",
            "contentType": "image/png",
            "mediaKey": "banners/images/2026-10-03/12c96e34-9e9b-4762-8634-07d7b267d8ea.png",
            "updatedAt": "2026-10-03T14:15:58.867Z",
            "id": "63f05563-62ba-4569-aab4-9308ee83f588",
            "sortOrder": 0,
            "title": "Macha, Entha chengayi, Namukku kurach snacks kazhichalo?",
            "mediaUrl": "https://pickleo-uat-productmediabucket-crczhrxw5sj3.s3.ap-south-1.amazonaws.com/banners/images/2026-10-03/12c96e34-9e9b-4762-8634-07d7b267d8ea.png?X-Amz-Algorithm=AWS4-HMAC-SHA256"
          },
          {
            "entityType": "BANNER",
            "mediaType": "image",
            "status": "Active",
            "createdAt": "2026-10-03T14:14:00.312Z",
            "createdBy": "srinivasafoodproducts9@gmail.com",
            "contentType": "image/png",
            "mediaKey": "banners/images/2026-10-03/287adc3d-3cfc-4156-a728-c1f73cb2805e.png",
            "updatedAt": "2026-10-03T14:14:00.312Z",
            "id": "1b5dc13a-496d-410f-a09e-d8a787c17345",
            "title": "Edhi Ramana gaadi Guntur Karam!!",
            "sortOrder": 0,
            "mediaUrl": "https://pickleo-uat-productmediabucket-crczhrxw5sj3.s3.ap-south-1.amazonaws.com/banners/images/2026-10-03/287adc3d-3cfc-4156-a728-c1f73cb2805e.png?X-Amz-Algorithm=AWS4-HMAC-SHA256"
          },
          {
            "entityType": "BANNER",
            "mediaType": "image",
            "status": "Active",
            "createdAt": "2026-10-03T14:13:01.410Z",
            "contentType": "image/png",
            "createdBy": "srinivasafoodproducts9@gmail.com",
            "mediaKey": "banners/images/2026-10-03/4d3d4e29-b88e-41d2-9e11-9b61a146d07f.png",
            "updatedAt": "2026-10-03T14:13:01.410Z",
            "id": "1a6de88b-2ce2-4ff9-b248-b28aa1c4c093",
            "sortOrder": 0,
            "title": "Coastal Andhra Ruchulu",
            "mediaUrl": "https://pickleo-uat-productmediabucket-crczhrxw5sj3.s3.ap-south-1.amazonaws.com/banners/images/2026-10-03/4d3d4e29-b88e-41d2-9e11-9b61a146d07f.png?X-Amz-Algorithm=AWS4-HMAC-SHA256"
          },
          {
            "entityType": "BANNER",
            "mediaType": "image",
            "status": "Active",
            "createdAt": "2026-10-03T14:12:00.259Z",
            "contentType": "image/png",
            "createdBy": "srinivasafoodproducts9@gmail.com",
            "mediaKey": "banners/images/2026-10-03/41e515de-68d4-4042-b2fd-9a96e1bc2b4c.png",
            "updatedAt": "2026-10-03T14:12:00.259Z",
            "id": "2caf4a73-ae20-4e45-95f9-474d1c4deabf",
            "sortOrder": 0,
            "title": "Are You Born in Powerful Panjab",
            "mediaUrl": "https://pickleo-uat-productmediabucket-crczhrxw5sj3.s3.ap-south-1.amazonaws.com/banners/images/2026-10-03/41e515de-68d4-4042-b2fd-9a96e1bc2b4c.png?X-Amz-Algorithm=AWS4-HMAC-SHA256"
          },
          {
            "entityType": "BANNER",
            "mediaType": "image",
            "status": "Active",
            "createdAt": "2026-10-03T14:11:16.363Z",
            "createdBy": "srinivasafoodproducts9@gmail.com",
            "contentType": "image/png",
            "mediaKey": "banners/images/2026-10-03/9c5c3ad2-e1cd-432e-8c96-a5d70c997d98.png",
            "updatedAt": "2026-10-03T14:11:16.363Z",
            "id": "f60648e7-360d-47fc-8acb-c7b44d241a02",
            "title": "What is your style",
            "sortOrder": 1,
            "mediaUrl": "https://pickleo-uat-productmediabucket-crczhrxw5sj3.s3.ap-south-1.amazonaws.com/banners/images/2026-10-03/9c5c3ad2-e1cd-432e-8c96-a5d70c997d98.png?X-Amz-Algorithm=AWS4-HMAC-SHA256"
          }
        ]
      };

      final items = (fullResponse['items'] as List)
          .map((m) => HomeBanner.fromJson(m as Map<String, dynamic>))
          .toList();

      expect(items.length, 6);

      // Verify all items are Active and images
      for (final b in items) {
        expect(b.isActive, isTrue);
        expect(b.isImage, isTrue);
        expect(b.entityType, 'BANNER');
        expect(b.createdBy, 'srinivasafoodproducts9@gmail.com');
        expect(b.mediaUrl, startsWith('https://'));
      }

      final processed = HomeBanner.processBanners(items);
      expect(processed.length, 6);
      expect(processed.first.title, contains("Nawabi"));
      expect(processed.last.title, "What is your style");
      expect(processed.last.sortOrder, 1);
    });
  });
}
