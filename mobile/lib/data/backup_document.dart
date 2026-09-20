import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../appearance/app_appearance.dart';
import '../domain/course_meeting.dart';

class TimetableBackup {
  const TimetableBackup({
    required this.createdAt,
    required this.schedule,
    required this.appearance,
    this.appVersion = 'unknown',
    this.backgroundBytes,
    this.backgroundExtension,
  });

  static const format = 'shanghaitech-timetable-backup';
  static const version = 1;
  final DateTime createdAt;
  final String appVersion;
  final SyncResult schedule;
  final AppAppearance appearance;
  final List<int>? backgroundBytes;
  final String? backgroundExtension;

  String encode() {
    final payload = <String, dynamic>{
      'format': format,
      'version': version,
      'createdAt': createdAt.toIso8601String(),
      'appVersion': appVersion,
      'schedule': schedule.toJson(),
      'appearance': appearance.toJson(includePath: false),
      if (backgroundBytes != null)
        'background': {
          'extension': backgroundExtension == 'png' ? 'png' : 'jpg',
          'base64': base64Encode(backgroundBytes!),
        },
    };
    final canonical = jsonEncode(payload);
    return const JsonEncoder.withIndent('  ').convert({
      ...payload,
      'sha256': sha256.convert(utf8.encode(canonical)).toString(),
    });
  }

  factory TimetableBackup.decode(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) throw const FormatException('这不是有效的课表备份');
    final document = Map<String, dynamic>.from(decoded);
    if (document['format'] != format || document['version'] != version) {
      throw const FormatException('备份格式或版本不受支持');
    }
    final checksum = document.remove('sha256')?.toString();
    final actual = sha256.convert(utf8.encode(jsonEncode(document))).toString();
    if (checksum == null || checksum != actual) {
      throw const FormatException('备份文件不完整或已被修改');
    }
    final rawSchedule = document['schedule'];
    final rawAppearance = document['appearance'];
    if (rawSchedule is! Map || rawAppearance is! Map) {
      throw const FormatException('备份缺少课表或外观数据');
    }
    final rawBackground = document['background'];
    List<int>? backgroundBytes;
    String? extension;
    if (rawBackground is Map) {
      final background = Map<String, dynamic>.from(rawBackground);
      try {
        backgroundBytes = base64Decode(background['base64']?.toString() ?? '');
      } catch (_) {
        throw const FormatException('背景图片数据损坏');
      }
      if (backgroundBytes.isEmpty) {
        throw const FormatException('背景图片数据损坏');
      }
      extension = background['extension'] == 'png' ? 'png' : 'jpg';
    }
    return TimetableBackup(
      createdAt:
          DateTime.tryParse(document['createdAt']?.toString() ?? '') ??
          (throw const FormatException('备份时间无效')),
      appVersion: document['appVersion']?.toString() ?? 'unknown',
      schedule: SyncResult.fromJson(Map<String, dynamic>.from(rawSchedule)),
      appearance: AppAppearance.fromJson(
        Map<String, dynamic>.from(rawAppearance),
      ),
      backgroundBytes: backgroundBytes,
      backgroundExtension: extension,
    );
  }
}
