import 'package:flutter/material.dart';

import '../../domain/course_meeting.dart';
import '../../domain/semester_calendar.dart';

class CalendarSettingsPage extends StatefulWidget {
  const CalendarSettingsPage({required this.schedule, super.key});
  final SyncResult schedule;
  @override
  State<CalendarSettingsPage> createState() => _CalendarSettingsPageState();
}

class _CalendarSettingsPageState extends State<CalendarSettingsPage> {
  late DateTime? _start = widget.schedule.calendar.firstMonday;
  late int _weeks = widget.schedule.calendar.totalWeeks;
  late final _periods = List<PeriodTime>.from(widget.schedule.periodTimes);
  final _form = GlobalKey<FormState>();

  Future<void> _pickDate() async {
    final now = SemesterCalendar.schoolToday;
    final value = await showDatePicker(
      context: context,
      helpText: '选择第一教学周的星期一',
      initialDate: _start ?? now.subtract(Duration(days: now.weekday - 1)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      selectableDayPredicate: (day) => day.weekday == DateTime.monday,
    );
    if (value != null && mounted) {
      setState(() => _start = SemesterCalendar.civil(value));
    }
  }

  Future<void> _editPeriod(int period) async {
    final old = widget.schedule.timeFor(period);
    final start = await showTimePicker(
      context: context,
      helpText: '第 $period 节开始时间',
      initialTime: TimeOfDay(
        hour: old == null ? 8 : int.parse(old.start.split(':')[0]),
        minute: old == null ? 0 : int.parse(old.start.split(':')[1]),
      ),
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      helpText: '第 $period 节结束时间',
      initialTime: TimeOfDay(hour: start.hour, minute: start.minute),
    );
    if (end == null || !mounted) return;
    if (end.hour * 60 + end.minute <= start.hour * 60 + start.minute) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('结束时间必须晚于开始时间')));
      return;
    }
    String format(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() {
      _periods.removeWhere((p) => p.period == period);
      _periods.add(
        PeriodTime(
          period: period,
          start: format(start),
          end: format(end),
          source: '用户设置',
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('学期与上课时间')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.schedule.termLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const Text('第一教学周的星期一用于计算每周日期；报到日和第一门课的日期不一定是这一天。学校日期尚未核实，请按校历确认。'),
          const SizedBox(height: 8),
          Text(
            '日期来源：${widget.schedule.calendar.source}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('第一教学周星期一'),
            subtitle: Text(
              _start == null
                  ? '尚未设置'
                  : '${_start!.year}年${_start!.month}月${_start!.day}日',
            ),
            trailing: const Icon(Icons.edit_calendar),
            onTap: _pickDate,
          ),
          TextFormField(
            initialValue: '$_weeks',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '学期总周数',
              helperText: '默认 20 周，请按本学期校历确认（包括无课的周）',
            ),
            validator: (value) {
              final n = int.tryParse(value ?? '');
              if (n == null || n < 1 || n > 30) return '请输入 1—30';
              if (n < widget.schedule.maxWeek) {
                return '课程已排到第 ${widget.schedule.maxWeek} 周';
              }
              return null;
            },
            onSaved: (value) => _weeks = int.parse(value!),
          ),
          const SizedBox(height: 20),
          Text('节次时间', style: Theme.of(context).textTheme.titleMedium),
          const Text('优先读取学校课表中的时间。未读取的节次显示“待同步”，也可点击手动设置。'),
          for (var i = 1; i <= 13; i++)
            Builder(
              builder: (context) {
                final rows = _periods.where((p) => p.period == i).toList();
                final label = rows.isEmpty
                    ? '待同步'
                    : rows
                          .map((p) => '${p.start}—${p.end}')
                          .toSet()
                          .join(' / ');
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('第 $i 节'),
                  subtitle: Text(label),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () => _editPeriod(i),
                );
              },
            ),
          FilledButton(
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              if (_start == null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('请先选择第一教学周的星期一')));
                return;
              }
              _form.currentState!.save();
              Navigator.pop(
                context,
                SyncResult(
                  termCode: widget.schedule.termCode,
                  termLabel: widget.schedule.termLabel,
                  meetings: widget.schedule.meetings,
                  syncedAt: widget.schedule.syncedAt,
                  periodTimes: _periods,
                  calendar: SemesterCalendar(
                    firstMonday: _start,
                    totalWeeks: _weeks,
                    source: '用户确认',
                    verifiedAt: DateTime.now(),
                  ),
                ),
              );
            },
            child: const Text('确认并保存'),
          ),
        ],
      ),
    ),
  );
}
