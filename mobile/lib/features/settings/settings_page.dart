import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../appearance/app_appearance.dart';
import '../../data/appearance_repository.dart';
import '../../data/backup_document.dart';
import '../../data/schedule_repository.dart';
import 'background_library_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.store,
    required this.appearance,
    required this.hasSchedule,
    this.onEditCalendar,
    super.key,
  });

  final ScheduleStore store;
  final AppearanceController appearance;
  final bool hasSchedule;
  final VoidCallback? onEditCalendar;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _busy = false;
  String _appVersion = '';
  late double _backgroundOverlay;
  late double _surfaceOpacity;
  late double _backgroundScale;
  late double _backgroundX;
  late double _backgroundY;

  @override
  void initState() {
    super.initState();
    _syncDraft();
    _loadAppVersion();
    widget.appearance.addListener(_appearanceChanged);
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = packageInfo.version);
    } on Object {
      // The version is supplementary information. A temporary platform-channel
      // failure must not prevent the settings page from opening.
    }
  }

  @override
  void dispose() {
    widget.appearance.removeListener(_appearanceChanged);
    super.dispose();
  }

  void _appearanceChanged() {
    if (!mounted) return;
    setState(_syncDraft);
  }

  void _syncDraft() {
    final value = widget.appearance.value;
    _backgroundOverlay = value.backgroundOverlay;
    _surfaceOpacity = value.timetableSurfaceOpacity;
    _backgroundScale = value.backgroundScale;
    _backgroundX = value.backgroundX;
    _backgroundY = value.backgroundY;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickBackground() => _run(() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1440,
      maxHeight: 2560,
      imageQuality: 82,
      requestFullMetadata: false,
    );
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    if (bytes.length > 12 * 1024 * 1024) {
      throw const FormatException('图片处理后仍然过大，请换一张图片');
    }
    final extension = photo.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    if (!mounted) return;
    final accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BackgroundPreviewPage.memory(bytes: bytes),
      ),
    );
    if (accepted != true) return;
    await widget.appearance.setBackground(bytes, extension: extension);
    if (mounted) setState(() {});
  });

  Future<void> _exportBackup() => _run(() async {
    final schedule = await widget.store.load();
    if (schedule == null) throw const FormatException('当前还没有可以备份的课表');
    final packageInfo = await PackageInfo.fromPlatform();
    List<int>? background;
    String? extension;
    final path = widget.appearance.value.backgroundPath;
    if (path != null && await File(path).exists()) {
      background = await File(path).readAsBytes();
      extension = path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    }
    final backup = TimetableBackup(
      createdAt: DateTime.now(),
      appVersion: packageInfo.version,
      schedule: schedule,
      appearance: widget.appearance.value,
      backgroundBytes: background,
      backgroundExtension: extension,
    );
    final now = DateTime.now();
    final fileName =
        '上科大课表备份_${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}.sttb';
    final pathResult = await FilePicker.platform.saveFile(
      dialogTitle: '保存课表备份',
      fileName: fileName,
      bytes: utf8.encode(backup.encode()),
    );
    if (pathResult != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('备份已经保存')));
    }
  });

  Future<void> _importBackup() => _run(() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择课表备份',
      type: FileType.custom,
      allowedExtensions: const ['sttb', 'json'],
      withData: true,
    );
    if (result == null) return;
    final picked = result.files.single;
    final bytes =
        picked.bytes ??
        (picked.path == null ? null : await File(picked.path!).readAsBytes());
    if (bytes == null) throw const FormatException('无法读取所选文件');
    final backup = TimetableBackup.decode(utf8.decode(bytes));
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认恢复备份'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(backup.schedule.termLabel),
            const SizedBox(height: 8),
            Text('课程安排：${backup.schedule.meetings.length} 条'),
            Text('创建时间：${_dateTime(backup.createdAt)}'),
            Text('包含背景图片：${backup.backgroundBytes == null ? '否' : '是'}'),
            const SizedBox(height: 12),
            const Text('恢复前会先通过数据库快照保留当前课表。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认恢复'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    final oldAppearance = widget.appearance.value;
    List<int>? oldBackground;
    String? oldBackgroundExtension;
    if (oldAppearance.backgroundPath != null) {
      final file = File(oldAppearance.backgroundPath!);
      if (await file.exists()) {
        oldBackground = await file.readAsBytes();
        oldBackgroundExtension = file.path.toLowerCase().endsWith('.png')
            ? 'png'
            : 'jpg';
      }
    }
    try {
      if (backup.backgroundBytes != null) {
        await widget.appearance.setBackground(
          backup.backgroundBytes!,
          extension: backup.backgroundExtension ?? 'jpg',
        );
        await widget.appearance.update(
          backup.appearance.copyWith(
            backgroundPath: widget.appearance.value.backgroundPath,
          ),
        );
      } else {
        await widget.appearance.clearBackground();
        await widget.appearance.update(
          backup.appearance.copyWith(clearBackground: true),
        );
      }
      // ScheduleRepository writes all course rows in one database transaction.
      // Applying it last means a database failure can still restore appearance.
      await widget.store.save(backup.schedule);
    } catch (_) {
      if (oldBackground != null) {
        await widget.appearance.setBackground(
          oldBackground,
          extension: oldBackgroundExtension ?? 'jpg',
        );
        await widget.appearance.update(
          oldAppearance.copyWith(
            backgroundPath: widget.appearance.value.backgroundPath,
          ),
        );
      } else {
        await widget.appearance.clearBackground();
        await widget.appearance.update(
          oldAppearance.copyWith(clearBackground: true),
        );
      }
      rethrow;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复完成'),
        content: const Text('课表和外观已经恢复。返回课表后会重新载入数据。'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('完成'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context, true);
  });

  @override
  Widget build(BuildContext context) {
    final appearance = widget.appearance.value;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _SectionTitle('外观'),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('主题'),
                subtitle: Text(_presetName(appearance.preset)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _busy ? null : _choosePreset,
              ),
              ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: const Text('深色模式'),
                subtitle: Text(
                  _themePreferenceName(appearance.themePreference),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _busy ? null : _chooseThemePreference,
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('背景图片'),
                subtitle: Text(appearance.hasBackground ? '已选择，点击更换' : '从相册选择'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _busy ? null : _pickBackground,
              ),
              ListTile(
                leading: const Icon(Icons.collections_bookmark_outlined),
                title: const Text('背景收藏与历史'),
                subtitle: const Text('预览、收藏、切换或删除使用过的背景'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _busy
                    ? null
                    : () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => BackgroundLibraryPage(
                            appearance: widget.appearance,
                          ),
                        ),
                      ),
              ),
              if (appearance.hasBackground) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(
                    '背景明暗',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Slider(
                  value: _backgroundOverlay,
                  min: 0,
                  max: .75,
                  divisions: 15,
                  label: '${(_backgroundOverlay * 100).round()}%',
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _backgroundOverlay = value),
                  onChangeEnd: _busy
                      ? null
                      : (value) => widget.appearance.update(
                          appearance.copyWith(backgroundOverlay: value),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Text(
                    '背景清晰度',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Slider(
                  value: .8 - _surfaceOpacity,
                  min: 0,
                  max: .8,
                  divisions: 16,
                  label: _surfaceOpacity == 0
                      ? '背景最清楚'
                      : '${((.8 - _surfaceOpacity) / .8 * 100).round()}%',
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _surfaceOpacity = .8 - value),
                  onChangeEnd: _busy
                      ? null
                      : (value) => widget.appearance.update(
                          appearance.copyWith(
                            timetableSurfaceOpacity: .8 - value,
                          ),
                        ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('向右背景更清楚，向左文字更容易阅读。'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Text(
                    '缩放',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Slider(
                  value: _backgroundScale,
                  min: 1,
                  max: 2.5,
                  divisions: 15,
                  label: '${_backgroundScale.toStringAsFixed(1)}×',
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _backgroundScale = value),
                  onChangeEnd: _busy
                      ? null
                      : (value) => widget.appearance.update(
                          appearance.copyWith(backgroundScale: value),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Text(
                    '水平位置',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Slider(
                  value: _backgroundX,
                  min: -1,
                  max: 1,
                  divisions: 20,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _backgroundX = value),
                  onChangeEnd: _busy
                      ? null
                      : (value) => widget.appearance.update(
                          appearance.copyWith(backgroundX: value),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Text(
                    '垂直位置',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Slider(
                  value: _backgroundY,
                  min: -1,
                  max: 1,
                  divisions: 20,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _backgroundY = value),
                  onChangeEnd: _busy
                      ? null
                      : (value) => widget.appearance.update(
                          appearance.copyWith(backgroundY: value),
                        ),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('停止使用背景'),
                  subtitle: const Text('图片仍保留在背景历史中'),
                  onTap: _busy
                      ? null
                      : () => _run(widget.appearance.clearBackground),
                ),
              ],
              ListTile(
                leading: const Icon(Icons.layers_outlined),
                title: const Text('课程卡片'),
                subtitle: Text(
                  appearance.cardStyle == TimetableCardStyle.solid
                      ? '实心'
                      : '半透明',
                ),
                trailing: Switch(
                  value: appearance.cardStyle == TimetableCardStyle.translucent,
                  onChanged: _busy
                      ? null
                      : (value) => widget.appearance.update(
                          appearance.copyWith(
                            cardStyle: value
                                ? TimetableCardStyle.translucent
                                : TimetableCardStyle.solid,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const _SectionTitle('课表与数据'),
          _SettingsCard(
            children: [
              if (widget.hasSchedule)
                ListTile(
                  leading: const Icon(Icons.tune_rounded),
                  title: const Text('学期与上课时间'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: widget.onEditCalendar,
                ),
              ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('导出完整备份'),
                subtitle: const Text('包含课表、外观和当前背景图片'),
                onTap: _busy || !widget.hasSchedule ? null : _exportBackup,
              ),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('从备份恢复'),
                subtitle: const Text('恢复前会验证文件完整性'),
                onTap: _busy ? null : _importBackup,
              ),
            ],
          ),
          const _SectionTitle('关于'),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(
                  _appVersion.isEmpty ? '上科大课表' : '上科大课表 v$_appVersion',
                ),
                subtitle: const Text(
                  '作者：夜斗绽星明\n'
                  '个人开发的非官方课表工具，与上海科技大学官方无隶属或授权关系。课程信息以学校教务系统为准。',
                ),
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Future<void> _choosePreset() async {
    final selected = await showModalBottomSheet<AppThemePreset>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('选择主题')),
            for (final preset in AppThemePreset.values)
              ListTile(
                title: Text(_presetName(preset)),
                subtitle: Text(_presetDescription(preset)),
                trailing: widget.appearance.value.preset == preset
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, preset),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await widget.appearance.update(
        widget.appearance.value.copyWith(preset: selected),
      );
      if (mounted) setState(() {});
    }
  }

  Future<void> _chooseThemePreference() async {
    final selected = await showModalBottomSheet<AppThemePreference>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('深色模式')),
            for (final value in AppThemePreference.values)
              ListTile(
                title: Text(_themePreferenceName(value)),
                trailing: widget.appearance.value.themePreference == value
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, value),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await widget.appearance.update(
        widget.appearance.value.copyWith(themePreference: selected),
      );
      if (mounted) setState(() {});
    }
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 22, 8, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

String _presetName(AppThemePreset value) => switch (value) {
  AppThemePreset.clean => '简洁白',
  AppThemePreset.moon => '月光黑',
  AppThemePreset.shanghaitech => '上科红',
};

String _presetDescription(AppThemePreset value) => switch (value) {
  AppThemePreset.clean => '明亮、清晰的默认课表',
  AppThemePreset.moon => '适合夜间使用的深蓝黑界面',
  AppThemePreset.shanghaitech => '以学校标志红为强调色',
};

String _themePreferenceName(AppThemePreference value) => switch (value) {
  AppThemePreference.system => '跟随系统',
  AppThemePreference.light => '始终浅色',
  AppThemePreference.dark => '始终深色',
  AppThemePreference.preset => '跟随当前主题',
};

String _two(int value) => value.toString().padLeft(2, '0');
String _dateTime(DateTime value) =>
    '${value.year}年${value.month}月${value.day}日 ${_two(value.hour)}:${_two(value.minute)}';

String _friendlyError(Object error) {
  if (error is FormatException) return error.message.toString();
  return '操作没有完成，现有数据没有被覆盖。请重试。';
}
