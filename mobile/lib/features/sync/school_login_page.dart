import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../domain/course_meeting.dart';

class SchoolLoginPage extends StatefulWidget {
  const SchoolLoginPage({super.key});

  @override
  State<SchoolLoginPage> createState() => _SchoolLoginPageState();
}

class _SchoolLoginPageState extends State<SchoolLoginPage> {
  static final Uri _portalUri = Uri.parse(
    'https://graduate.shanghaitech.edu.cn/gsapp/sys/yjsemaphome/portal/index.do',
  );

  late final WebViewController _controller;
  var _loading = true;
  var _reading = false;
  var _status = '请在学校官方页面完成登录';
  Timer? _readTimeout;
  var _readSerial = 0;

  @override
  void dispose() {
    _readTimeout?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF6F8F8))
      ..addJavaScriptChannel(
        'CourseSync',
        onMessageReceived: _handleBridgeMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (url) {
            if (!mounted) return;
            final uri = Uri.tryParse(url);
            setState(() {
              _loading = false;
              _status = uri?.host == 'graduate.shanghaitech.edu.cn'
                  ? '已进入研究生系统，可以读取课表'
                  : '请在学校官方页面完成登录';
            });
          },
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame != true) return;
            setState(() {
              _loading = false;
              _status = '页面加载失败，请检查网络后重试';
            });
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null ||
                uri.scheme != 'https' ||
                !_isTrustedHost(uri.host)) {
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已阻止离开上海科技大学网站')));
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(_portalUri);
  }

  bool _isTrustedHost(String host) {
    return host == 'shanghaitech.edu.cn' ||
        host.endsWith('.shanghaitech.edu.cn');
  }

  Future<void> _readSchedule() async {
    if (_reading) return;
    final readId = ++_readSerial;
    setState(() {
      _reading = true;
      _status = '正在从学校系统读取课表…';
    });
    _readTimeout?.cancel();
    _readTimeout = Timer(const Duration(seconds: 35), () {
      if (mounted && _reading) {
        setState(() {
          _reading = false;
          _status = '学校响应超时，请检查网络后重新读取';
        });
      }
    });

    const script = r'''
(function () {
  const send = (payload) => CourseSync.postMessage(JSON.stringify({...payload, requestId: __SYNC_REQUEST__}));
  try {
    const frame = document.getElementById('iframeContent_wdkbappshtechxskcb');
    if (!frame || !frame.contentWindow || !frame.contentDocument) {
      send({ok: false, error: '尚未打开学生课程表，请先登录并进入“我的课表”。'});
      return;
    }

    const termSelect = frame.contentDocument.getElementById('query_xnxq');
    if (!termSelect || !termSelect.value) {
      send({ok: false, error: '课表页面仍在加载，请稍后再试。'});
      return;
    }

    const termCode = termSelect.value;
    const termLabel = termSelect.options[termSelect.selectedIndex]?.textContent?.trim() || '当前学期';
    const endpoint = new URL('/gsapp/sys/wdkbappshtech/xskbBy/loadPkjg.do', frame.src).href;
    const form = new URLSearchParams({XNXQDM: termCode, ZC: ''});

    frame.contentWindow.fetch(endpoint, {
      method: 'POST',
      credentials: 'include',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'X-Requested-With': 'XMLHttpRequest'
      },
      body: form.toString()
    })
      .then((response) => {
        if (!response.ok) throw new Error('学校服务器返回 ' + response.status);
        return response.json();
      })
      .then((data) => {
        if (termSelect.value !== termCode) throw new Error('读取期间学期已切换，请重新读取');
        const formatTime = (value) => {
          const s = String(value ?? '').replace(':', '').padStart(4, '0');
          return /^\d{4}$/.test(s) ? s.slice(0, 2) + ':' + s.slice(2) : '';
        };
        const periodTimes = [];
        for (const scheme of data.jcfaList || []) {
          for (const p of scheme.skjcList || []) {
            const start = formatTime(p.KSSJ), end = formatTime(p.JSSJ);
            if (start && end && Number(p.DM) > 0) {
              periodTimes.push({period: Number(p.DM), start, end, scheme: String(scheme.DM), source: '学校节次方案'});
            }
          }
        }
        // Cross-check visible first-class dates against week/day text. This is
        // a suggestion only; it is never treated as an official semester date.
        const candidates = [];
        for (const row of frame.contentDocument.querySelectorAll('#xsjxrwDiv tr')) {
          const texts = Array.from(row.querySelectorAll('td')).map(c => c.textContent.trim());
          const dateText = texts.find(t => /^\d{4}-\d{2}-\d{2}$/.test(t));
          const scheduleText = texts.find(t => /周\s*星期[一二三四五六日]/.test(t));
          if (!dateText || !scheduleText) continue;
          const match = scheduleText.match(/^(\d+)(?:-\d+)?周\s*星期([一二三四五六日])/);
          if (!match) continue;
          const weekday = '一二三四五六日'.indexOf(match[2]) + 1;
          const date = new Date(dateText + 'T00:00:00Z');
          if ((date.getUTCDay() || 7) !== weekday) continue;
          date.setUTCDate(date.getUTCDate() - (Number(match[1]) - 1) * 7 - weekday + 1);
          candidates.push(date.toISOString().slice(0, 10));
        }
        const suggestedMonday = candidates.length >= 2 && new Set(candidates).size === 1 ? candidates[0] : null;
        send({ok: true, termCode, termLabel, data, periodTimes, suggestedMonday});
      })
      .catch((error) => send({ok: false, error: '读取失败：' + error.message}));
  } catch (error) {
    send({ok: false, error: '无法读取课表：' + error.message});
  }
})();
''';

    try {
      await _controller.runJavaScript(
        script.replaceAll('__SYNC_REQUEST__', '$readId'),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reading = false;
        _status = '无法连接课表页面，请重新进入“学生课程表”';
      });
    }
  }

  void _handleBridgeMessage(JavaScriptMessage message) {
    if (!_reading || !mounted) return;
    try {
      final decoded = jsonDecode(message.message);
      if (decoded is! Map) throw const FormatException('课表消息格式错误');
      final payload = Map<String, dynamic>.from(decoded);
      if (payload['requestId'] != _readSerial) return;
      _readTimeout?.cancel();
      if (payload['ok'] != true) {
        throw FormatException(payload['error']?.toString() ?? '读取失败');
      }

      final result = SyncResult.fromBridgeMessage(payload);
      if (!mounted) return;
      setState(() {
        _reading = false;
        _status = '已读取 ${result.meetings.length} 条排课安排';
      });
      Navigator.of(context).pop(result);
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _reading = false;
        _status = error.message.toString();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reading = false;
        _status = '课表数据无法解析，请保留原课表并稍后重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录学校并同步'),
        actions: [
          IconButton(
            tooltip: '刷新页面',
            onPressed: _reading ? null : _controller.reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_status)),
                ],
              ),
            ),
          ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _reading ? null : _readSchedule,
          icon: _reading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync_rounded),
          label: Text(_reading ? '正在读取…' : '读取当前课表'),
        ),
      ),
    );
  }
}
