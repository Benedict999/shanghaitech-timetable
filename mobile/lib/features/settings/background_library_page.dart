import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/appearance_repository.dart';

class BackgroundPreviewPage extends StatelessWidget {
  BackgroundPreviewPage.memory({
    required Uint8List bytes,
    this.title = '预览背景',
    this.confirmLabel = '设为背景',
    super.key,
  }) : image = MemoryImage(bytes);

  BackgroundPreviewPage.file({
    required String path,
    this.title = '预览背景',
    this.confirmLabel = '使用这张背景',
    super.key,
  }) : image = FileImage(File(path));

  final ImageProvider image;
  final String title;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: Text(title),
      foregroundColor: Colors.white,
      backgroundColor: Colors.black,
    ),
    body: Column(
      children: [
        Expanded(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            boundaryMargin: const EdgeInsets.all(120),
            child: SizedBox.expand(
              child: Image(image: image, fit: BoxFit.contain),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            color: Colors.black,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class BackgroundLibraryPage extends StatefulWidget {
  const BackgroundLibraryPage({required this.appearance, super.key});

  final AppearanceController appearance;

  @override
  State<BackgroundLibraryPage> createState() => _BackgroundLibraryPageState();
}

class _BackgroundLibraryPageState extends State<BackgroundLibraryPage> {
  List<BackgroundEntry>? _entries;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await widget.appearance.loadBackgrounds();
    if (mounted) setState(() => _entries = entries);
  }

  Future<void> _preview(BackgroundEntry entry) async {
    final use = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BackgroundPreviewPage.file(path: entry.path),
      ),
    );
    if (use != true || !mounted) return;
    setState(() => _busy = true);
    await widget.appearance.useBackground(entry.path);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('背景已经更换')));
  }

  Future<void> _favorite(BackgroundEntry entry) async {
    await widget.appearance.setBackgroundFavorite(entry.path, !entry.favorite);
    await _load();
  }

  Future<void> _delete(BackgroundEntry entry) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这张背景？'),
        content: const Text('图片会从应用的背景历史中删除，无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    await widget.appearance.deleteBackground(entry.path);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      appBar: AppBar(title: const Text('背景收藏与历史')),
      body: entries == null
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
          ? const Center(child: Text('还没有使用过背景图片'))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: .72,
              ),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final current =
                    widget.appearance.value.backgroundPath == entry.path;
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _busy ? null : () => _preview(entry),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(entry.path),
                          fit: BoxFit.cover,
                          cacheWidth: 600,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Colors.black12,
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                        Positioned(
                          left: 8,
                          top: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                current ? '正在使用' : _date(entry.addedAt),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 2,
                          top: 2,
                          child: IconButton.filledTonal(
                            tooltip: entry.favorite ? '取消收藏' : '收藏',
                            onPressed: _busy ? null : () => _favorite(entry),
                            icon: Icon(
                              entry.favorite
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: IconButton.filledTonal(
                            tooltip: '删除',
                            onPressed: _busy ? null : () => _delete(entry),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

String _date(DateTime value) => '${value.month}/${value.day}';
