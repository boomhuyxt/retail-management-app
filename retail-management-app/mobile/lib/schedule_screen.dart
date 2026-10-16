import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'core/api_config.dart';
import 'core/schedule_service.dart';
import 'theme.dart';

class ShiftScheduleScreen extends StatefulWidget {
  final Future<List<ScheduleShift>> Function(DateTime, DateTime)? loadSchedule;
  const ShiftScheduleScreen({super.key, this.loadSchedule});

  @override
  State<ShiftScheduleScreen> createState() => _ShiftScheduleScreenState();
}

class _ShiftScheduleScreenState extends State<ShiftScheduleScreen>
    with WidgetsBindingObserver {
  DateTime _selectedDate = scheduleToday();
  List<ScheduleShift> _shifts = [];
  bool _loading = true;
  String? _error;
  int _request = 0;
  DateTime get _monday =>
      _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));

  void _showChangeServerDialog() {
    final urlController = TextEditingController(text: ApiConfig.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Cấu hình kết nối API Server',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Địa chỉ Backend ASP.NET Core:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                hintText: 'http://localhost:5000',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text('Localhost (USB/Emulator)', style: TextStyle(fontSize: 11)),
                  onPressed: () => urlController.text = 'http://localhost:5000',
                ),
                ActionChip(
                  label: const Text('Wi-Fi LAN', style: TextStyle(fontSize: 11)),
                  onPressed: () => urlController.text = 'http://192.168.2.248:5000',
                ),
                ActionChip(
                  label: const Text('Deploy Online', style: TextStyle(fontSize: 11)),
                  onPressed: () => urlController.text = 'https://www.manage365.io.vn',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
            ),
            onPressed: () {
              ApiConfig.baseUrl = urlController.text.trim();
              Navigator.pop(ctx);
              _load();
            },
            child: const Text(
              'Lưu & Thử lại',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    final from = _monday;
    setState(() {
      _loading = true;
      _error = null;
      _shifts = [];
    });
    try {
      final items = await (widget.loadSchedule ?? ScheduleService.getSchedule)(
        from,
        from.add(const Duration(days: 6)),
      );
      if (!mounted || request != _request) return;
      setState(() {
        _shifts = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _move(int weeks) {
    setState(
      () => _selectedDate = _selectedDate.add(Duration(days: weeks * 7)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) => _monday.add(Duration(days: i)));
    final shifts = _shifts
        .where(
          (s) =>
              s.date == scheduleDate(_selectedDate) && s.status != 'Cancelled',
        )
        .toList();
    return Scaffold(
      backgroundColor: AppColors.bgLightCream,
      appBar: AppBar(
        title: const Text('Lịch làm việc'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _selectedDate = scheduleToday());
              _load();
            },
            child: const Text('Hôm nay'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Tuần trước',
                  onPressed: () => _move(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Flexible(
                  child: Text(
                    '${DateFormat('dd/MM').format(days.first)} – ${DateFormat('dd/MM/yyyy').format(days.last)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Tuần sau',
                  onPressed: () => _move(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: days.map((day) {
                  final selected =
                      scheduleDate(day) == scheduleDate(_selectedDate);
                  final count = _shifts
                      .where(
                        (s) =>
                            s.date == scheduleDate(day) &&
                            s.status != 'Cancelled',
                      )
                      .length;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Semantics(
                        selected: selected,
                        child: InkWell(
                          onTap: () => setState(() => _selectedDate = day),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primaryOrange
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  day.weekday == 7
                                      ? 'CN'
                                      : 'T${day.weekday + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: selected
                                        ? Colors.white
                                        : Colors.black54,
                                  ),
                                ),
                                Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: selected
                                        ? Colors.white
                                        : AppColors.textDark,
                                  ),
                                ),
                                Text(
                                  _loading ? '…' : '$count ca',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: selected
                                        ? Colors.white
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ngày ${DateFormat('dd/MM/yyyy').format(_selectedDate)} · UTC+7',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tải lại lịch',
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _loading
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(48),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ],
                      )
                    : _error != null
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _load,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Thử lại'),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryOrange,
                                ),
                                onPressed: _showChangeServerDialog,
                                icon: const Icon(Icons.dns, size: 18, color: Colors.white),
                                label: const Text(
                                  'Đổi máy chủ API',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        children: shifts.isEmpty
                            ? const [
                                Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Text(
                                    'Chưa được phân ca trong ngày này.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ]
                            : shifts.map(_card).toList(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(ScheduleShift shift) {
    final rawColor = RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(shift.color)
        ? shift.color.substring(1)
        : 'e96900';
    final color = Color(int.parse('ff$rawColor', radix: 16));
    return Card(
      key: ValueKey(shift.assignmentId),
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shift.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '${shift.startTime} – ${shift.endTime}${shift.isOvernight ? ' (kết thúc ngày hôm sau)' : ''}',
            ),
            const SizedBox(height: 8),
            Text(
              shift.statusLabel,
              style: TextStyle(
                color: shift.checkOutAt != null ? Colors.green.shade700 : color,
              ),
            ),
            if (shift.note?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(shift.note!),
              ),
          ],
        ),
      ),
    );
  }
}
