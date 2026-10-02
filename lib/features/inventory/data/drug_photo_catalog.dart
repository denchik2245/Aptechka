import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final drugPhotoCatalogProvider = Provider((ref) => DrugPhotoCatalog());
final drugPhotoProvider = FutureProvider.family<DrugPhoto?, String?>((
  ref,
  gtin,
) {
  return ref.watch(drugPhotoCatalogProvider).find(gtin);
});

class DrugPhoto {
  const DrugPhoto({required this.asset, required this.isDemo});
  final String asset;
  final bool isDemo;
  String get credit =>
      isDemo ? 'РЛС Аврора · тестовый доступ' : 'Фото: РЛС Аврора';
}

class DrugPhotoCatalog {
  DrugPhotoCatalog({Future<String> Function()? loadAsset})
    : _loadAsset =
          loadAsset ??
          (() => rootBundle.loadString('assets/drug_photos/manifest.json'));

  final Future<String> Function() _loadAsset;
  Future<Map<String, DrugPhoto>>? _pending;

  Future<DrugPhoto?> find(String? gtin) async {
    if (gtin == null || !RegExp(r'^\d{14}$').hasMatch(gtin)) return null;
    final pending = _pending ??= _load();
    try {
      return (await pending)[gtin];
    } catch (_) {
      if (identical(_pending, pending)) _pending = null;
      rethrow;
    }
  }

  Future<Map<String, DrugPhoto>> _load() async {
    final data = jsonDecode(await _loadAsset()) as Map<String, dynamic>;
    final mode = data['usage'];
    if (data['schemaVersion'] != 1 ||
        data['source'] != 'РЛС Аврора' ||
        !['demo', 'licensed'].contains(mode) ||
        (mode == 'licensed' &&
            (data['rightsReference'] as String).trim().isEmpty)) {
      throw const FormatException('Неизвестный формат фотографий');
    }
    final photos = <String, DrugPhoto>{};
    for (final raw in data['entries'] as List) {
      final entry = raw as Map<String, dynamic>;
      final gtin = entry['gtin'] as String;
      final asset = entry['asset'] as String;
      if (!RegExp(r'^\d{14}$').hasMatch(gtin) ||
          photos.containsKey(gtin) ||
          !RegExp(r'^assets/drug_photos/[a-f0-9]{64}\.(png|jpg|gif|webp)$')
              .hasMatch(asset)) {
        throw const FormatException('Повреждена запись фотографии');
      }
      photos[gtin] = DrugPhoto(asset: asset, isDemo: mode == 'demo');
    }
    return photos;
  }
}
