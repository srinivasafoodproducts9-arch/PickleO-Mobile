class HomeBanner {
  final String id;
  final String title;
  final String mediaType;
  final String mediaKey;
  final String contentType;
  final String mediaUrl;
  final String status;
  final int sortOrder;
  final String? createdAt;
  final String? updatedAt;
  final String entityType;
  final String createdBy;

  HomeBanner({
    required this.id,
    required this.title,
    required this.mediaType,
    this.mediaKey = '',
    this.contentType = '',
    required this.mediaUrl,
    required this.status,
    required this.sortOrder,
    this.createdAt,
    this.updatedAt,
    this.entityType = 'BANNER',
    this.createdBy = '',
  });

  /// Check if banner is active
  bool get isActive => status.trim().toLowerCase() == 'active';

  /// Check if media is video
  bool get isVideo {
    final type = mediaType.trim().toLowerCase();
    final content = contentType.trim().toLowerCase();
    final url = mediaUrl.trim().toLowerCase();
    return type == 'video' ||
        content.startsWith('video/') ||
        url.endsWith('.mp4') ||
        url.endsWith('.mov') ||
        url.endsWith('.webm') ||
        url.endsWith('.m3u8');
  }

  /// Check if media is image
  bool get isImage => !isVideo;

  factory HomeBanner.fromJson(Map<String, dynamic> json) {
    final mediaKey = json['mediaKey']?.toString() ??
        json['media_key']?.toString() ??
        '';
    String mediaUrl = json['mediaUrl']?.toString() ??
        json['media_url']?.toString() ??
        json['url']?.toString() ??
        '';
    if (mediaUrl.isEmpty && mediaKey.isNotEmpty) {
      mediaUrl =
          'https://pickleo-uat-productmediabucket-crczhrxw5sj3.s3.ap-south-1.amazonaws.com/$mediaKey';
    }

    return HomeBanner(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      mediaType: json['mediaType']?.toString() ??
          json['media_type']?.toString() ??
          'image',
      mediaKey: mediaKey,
      contentType: json['contentType']?.toString() ??
          json['content_type']?.toString() ??
          '',
      mediaUrl: mediaUrl,
      status: json['status']?.toString() ?? 'Active',
      sortOrder: (json['sortOrder'] is num)
          ? (json['sortOrder'] as num).toInt()
          : (int.tryParse(json['sortOrder']?.toString() ??
                  json['sort_order']?.toString() ??
                  '0') ??
              0),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      entityType: json['entityType']?.toString() ??
          json['entity_type']?.toString() ??
          'BANNER',
      createdBy: json['createdBy']?.toString() ??
          json['created_by']?.toString() ??
          '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'mediaType': mediaType,
      'mediaKey': mediaKey,
      'contentType': contentType,
      'mediaUrl': mediaUrl,
      'status': status,
      'sortOrder': sortOrder,
      'entityType': entityType,
      'createdBy': createdBy,
      if (createdAt != null) 'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  /// Filters active banners and sorts them:
  /// If sort order is all 0, preserve API list order;
  /// Otherwise sort ascending by sortOrder.
  static List<HomeBanner> processBanners(List<HomeBanner> all) {
    final active = all.where((b) => b.isActive).toList();
    if (active.isEmpty) return [];

    final bool allZero = active.every((b) => b.sortOrder == 0);
    if (!allZero) {
      active.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    return active;
  }

  /// Check if an S3 pre-signed URL has expired based on X-Amz-Date & X-Amz-Expires query params
  static bool isUrlExpired(String? url) {
    if (url == null || url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      final dateStr = uri.queryParameters['X-Amz-Date'];
      final expiresStr = uri.queryParameters['X-Amz-Expires'];
      if (dateStr != null && expiresStr != null && dateStr.length >= 15) {
        final year = int.parse(dateStr.substring(0, 4));
        final month = int.parse(dateStr.substring(4, 6));
        final day = int.parse(dateStr.substring(6, 8));
        final hour = int.parse(dateStr.substring(9, 11));
        final minute = int.parse(dateStr.substring(11, 13));
        final second = int.parse(dateStr.substring(13, 15));
        final signTime = DateTime.utc(year, month, day, hour, minute, second);
        final expireSeconds = int.parse(expiresStr);
        final expireTime = signTime.add(Duration(seconds: expireSeconds));
        // Expired if current UTC time is after or within 30 seconds of expiry
        return DateTime.now()
            .toUtc()
            .isAfter(expireTime.subtract(const Duration(seconds: 30)));
      }
    } catch (_) {}
    return false;
  }
}
