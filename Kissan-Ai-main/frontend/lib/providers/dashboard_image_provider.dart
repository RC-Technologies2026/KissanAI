import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Curated pools of high-quality agriculture images for each dashboard card.
///
/// The card shown rotates based on the day of the month, so the dashboard
/// feels fresh every day while images are cached after the first load.
class DashboardImageProvider {
  DashboardImageProvider._();

  /// Low-resolution query params keep first download fast and cache small.
  static const _imgParams = '?w=480&q=80&auto=format&fit=crop';

  static final Map<String, List<String>> _pools = {
    'disease': [
      'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b$_imgParams',
      'https://images.unsplash.com/photo-1591857177580-dc82b9ac4e1e$_imgParams',
      'https://images.unsplash.com/photo-1464226184884-fa280b87c399$_imgParams',
      'https://images.unsplash.com/photo-1500382017468-9049fed747ef$_imgParams',
    ],
    'pest': [
      'https://images.unsplash.com/photo-1500651230702-0e2d8a49d4e7$_imgParams',
      'https://images.unsplash.com/photo-1470252649378-9c29740c9fa8$_imgParams',
      'https://images.unsplash.com/photo-1530836369250-ef72a3f5cda8$_imgParams',
      'https://images.unsplash.com/photo-1592982537447-7440770cbfc9$_imgParams',
    ],
    'crop': [
      'https://images.unsplash.com/photo-1523348837708-15d4a09cfac2$_imgParams',
      'https://images.unsplash.com/photo-1625246333195-78d9c38ad449$_imgParams',
      'https://images.unsplash.com/photo-1595855709915-fa457a976b73$_imgParams',
      'https://images.unsplash.com/photo-1560493676-04071c5f467b$_imgParams',
    ],
    'irrigation': [
      'https://images.unsplash.com/photo-1416879595882-3373a0480b5b$_imgParams',
      'https://images.unsplash.com/photo-1500937386664-56d1dfef3854$_imgParams',
      'https://images.unsplash.com/photo-1466692476868-aef1dfb1e735$_imgParams',
      'https://images.unsplash.com/photo-1586771107445-d3ca888129ff$_imgParams',
    ],
    'chat': [
      'https://images.unsplash.com/photo-1500382017468-9049fed747ef$_imgParams',
      'https://images.unsplash.com/photo-1592982537447-7440770cbfc9$_imgParams',
      'https://images.unsplash.com/photo-1560493676-04071c5f467b$_imgParams',
      'https://images.unsplash.com/photo-1464226184884-fa280b87c399$_imgParams',
    ],
    'history': [
      'https://images.unsplash.com/photo-1605000797499-95a51c5269ae$_imgParams',
      'https://images.unsplash.com/photo-1595855709915-fa457a976b73$_imgParams',
      'https://images.unsplash.com/photo-1500382017468-9049fed747ef$_imgParams',
      'https://images.unsplash.com/photo-1625246333195-78d9c38ad449$_imgParams',
    ],
    'plots': [
      'https://images.unsplash.com/photo-1500382017468-9049fed747ef$_imgParams',
      'https://images.unsplash.com/photo-1560493676-04071c5f467b$_imgParams',
      'https://images.unsplash.com/photo-1595855709915-fa457a976b73$_imgParams',
      'https://images.unsplash.com/photo-1625246333195-78d9c38ad449$_imgParams',
    ],
    'plants': [
      'https://images.unsplash.com/photo-1463936575829-25148e1db1b8$_imgParams',
      'https://images.unsplash.com/photo-1459156212016-c812468e2115$_imgParams',
      'https://images.unsplash.com/photo-1416879595882-3373a0480b5b$_imgParams',
      'https://images.unsplash.com/photo-1501004318641-b39e6451bec6$_imgParams',
    ],
  };

  /// Returns the image URL to show today for [cardKey].
  static String urlFor(String cardKey) {
    final pool = _pools[cardKey] ?? _pools['crop']!;
    final day = DateTime.now().day;
    return pool[day % pool.length];
  }

  /// Precaches all dashboard images in the background so subsequent opens are instant.
  static Future<void> precacheAll(BuildContext context) async {
    final manager = DefaultCacheManager();
    for (final pool in _pools.values) {
      for (final url in pool) {
        try {
          await manager.getSingleFile(url);
        } catch (_) {
          // Ignore precache failures; the card will fall back to the asset image.
        }
      }
    }
  }

  /// Returns a [CachedNetworkImageProvider] for the current card image.
  static ImageProvider imageProvider(String cardKey) {
    return CachedNetworkImageProvider(urlFor(cardKey));
  }
}
