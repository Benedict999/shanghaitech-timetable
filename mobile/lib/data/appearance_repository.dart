import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../appearance/app_appearance.dart';

abstract interface class AppearanceStore {
  Future<AppAppearance> load();
  Future<void> save(AppAppearance value);
  Future<String> saveBackgroundBytes(
    List<int> bytes, {
    String extension = 'jpg',
  });
  Future<void> removeBackground(String? path);
  Future<List<BackgroundEntry>> loadBackgrounds(String? activePath);
  Future<void> setBackgroundFavorite(String path, bool favorite);
}

class BackgroundEntry {
  const BackgroundEntry({
    required this.path,
    required this.addedAt,
    required this.favorite,
  });

  final String path;
  final DateTime addedAt;
  final bool favorite;
}

class AppearanceRepository implements AppearanceStore {
  AppearanceRepository({
    SharedPreferencesAsync? preferences,
    Future<Directory> Function()? documentsDirectory,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  static const _key = 'appearance_v1';
  static const _backgroundsKey = 'background_library_v1';
  final SharedPreferencesAsync _preferences;
  final Future<Directory> Function() _documentsDirectory;

  @override
  Future<AppAppearance> load() async {
    final encoded = await _preferences.getString(_key);
    if (encoded == null || encoded.isEmpty) return const AppAppearance();
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return const AppAppearance();
      final value = AppAppearance.fromJson(Map<String, dynamic>.from(decoded));
      if (!value.hasBackground || await File(value.backgroundPath!).exists()) {
        return value;
      }
      return value.copyWith(clearBackground: true);
    } catch (_) {
      return const AppAppearance();
    }
  }

  @override
  Future<void> save(AppAppearance value) =>
      _preferences.setString(_key, jsonEncode(value.toJson()));

  @override
  Future<String> saveBackgroundBytes(
    List<int> bytes, {
    String extension = 'jpg',
  }) async {
    final root = await _documentsDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}backgrounds',
    );
    await directory.create(recursive: true);
    final safeExtension = extension.toLowerCase() == 'png' ? 'png' : 'jpg';
    final digest = sha256.convert(bytes).toString().substring(0, 20);
    final target = File(
      '${directory.path}${Platform.pathSeparator}$digest.$safeExtension',
    );
    if (!await target.exists()) await target.writeAsBytes(bytes, flush: true);
    final metadata = await _readBackgroundMetadata();
    metadata.putIfAbsent(
      target.path,
      () => {'addedAt': DateTime.now().toIso8601String(), 'favorite': false},
    );
    await _trimBackgroundHistory(metadata, keepPath: target.path);
    await _writeBackgroundMetadata(metadata);
    return target.path;
  }

  @override
  Future<void> removeBackground(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
    final metadata = await _readBackgroundMetadata()
      ..remove(path);
    await _writeBackgroundMetadata(metadata);
  }

  @override
  Future<List<BackgroundEntry>> loadBackgrounds(String? activePath) async {
    final metadata = await _readBackgroundMetadata();
    if (activePath != null &&
        await File(activePath).exists() &&
        !metadata.containsKey(activePath)) {
      metadata[activePath] = {
        'addedAt': DateTime.now().toIso8601String(),
        'favorite': false,
      };
      await _writeBackgroundMetadata(metadata);
    }
    final entries = <BackgroundEntry>[];
    for (final item in metadata.entries) {
      if (!await File(item.key).exists()) continue;
      entries.add(
        BackgroundEntry(
          path: item.key,
          addedAt:
              DateTime.tryParse(item.value['addedAt']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
          favorite: item.value['favorite'] == true,
        ),
      );
    }
    entries.sort((a, b) {
      if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
      return b.addedAt.compareTo(a.addedAt);
    });
    return entries;
  }

  @override
  Future<void> setBackgroundFavorite(String path, bool favorite) async {
    final metadata = await _readBackgroundMetadata();
    final old =
        metadata[path] ??
        <String, dynamic>{'addedAt': DateTime.now().toIso8601String()};
    metadata[path] = {...old, 'favorite': favorite};
    await _writeBackgroundMetadata(metadata);
  }

  Future<Map<String, Map<String, dynamic>>> _readBackgroundMetadata() async {
    final encoded = await _preferences.getString(_backgroundsKey);
    if (encoded == null || encoded.isEmpty) return {};
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return {};
      return decoded.map(
        (key, value) => MapEntry(
          key.toString(),
          value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{},
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeBackgroundMetadata(
    Map<String, Map<String, dynamic>> value,
  ) => _preferences.setString(_backgroundsKey, jsonEncode(value));

  Future<void> _trimBackgroundHistory(
    Map<String, Map<String, dynamic>> metadata, {
    required String keepPath,
  }) async {
    final activePath = (await load()).backgroundPath;
    final ordinary =
        metadata.entries
            .where((entry) => entry.value['favorite'] != true)
            .toList()
          ..sort((a, b) {
            final aTime = DateTime.tryParse(
              a.value['addedAt']?.toString() ?? '',
            );
            final bTime = DateTime.tryParse(
              b.value['addedAt']?.toString() ?? '',
            );
            return (bTime ?? DateTime(0)).compareTo(aTime ?? DateTime(0));
          });
    for (final entry in ordinary.skip(20).toList()) {
      if (entry.key == keepPath || entry.key == activePath) continue;
      final file = File(entry.key);
      if (await file.exists()) await file.delete();
      metadata.remove(entry.key);
    }
  }
}

class AppearanceController extends ChangeNotifier {
  AppearanceController(this.repository);

  final AppearanceStore repository;
  AppAppearance _value = const AppAppearance();
  AppAppearance get value => _value;
  bool _ready = false;
  bool get ready => _ready;

  Future<void> load() async {
    _value = await repository.load();
    _ready = true;
    notifyListeners();
  }

  Future<void> update(AppAppearance value) async {
    _value = value;
    notifyListeners();
    await repository.save(value);
  }

  Future<void> setBackground(
    List<int> bytes, {
    String extension = 'jpg',
  }) async {
    final path = await repository.saveBackgroundBytes(
      bytes,
      extension: extension,
    );
    await update(
      _value.copyWith(
        backgroundPath: path,
        cardStyle: TimetableCardStyle.translucent,
      ),
    );
  }

  Future<void> useBackground(String path) => update(
    _value.copyWith(
      backgroundPath: path,
      cardStyle: TimetableCardStyle.translucent,
    ),
  );

  Future<List<BackgroundEntry>> loadBackgrounds() =>
      repository.loadBackgrounds(_value.backgroundPath);

  Future<void> setBackgroundFavorite(String path, bool favorite) =>
      repository.setBackgroundFavorite(path, favorite);

  Future<void> deleteBackground(String path) async {
    if (_value.backgroundPath == path) {
      await update(_value.copyWith(clearBackground: true));
    }
    await repository.removeBackground(path);
  }

  Future<void> clearBackground() async {
    await repository.loadBackgrounds(_value.backgroundPath);
    await update(_value.copyWith(clearBackground: true));
  }
}
