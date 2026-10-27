import 'package:flutter/material.dart';

import 'core/attendance_service.dart';
import 'theme.dart';

enum _HistoryPeriod { day, month }

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key, required this.isAdmin});

  final bool isAdmin;

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  _HistoryPeriod _period = _HistoryPeriod.month;
  DateTime _selectedDate = DateTime.now();
  late Future<List<ShiftRecordModel>> _history;
  final List<AdminAttendanceHistoryModel> _additionalAdminRecords = [];
  List<AdminAttendanceHistoryModel> _firstAdminPage = [];
  int _adminPage = 1;
  int _adminTotalCount = 0;
  bool _loadingMore = false;
  String? _loadMoreError;

  DateTime get _fromDate => _period == _HistoryPeriod.day
      ? DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)
      : DateTime(_selectedDate.year, _selectedDate.month);

  DateTime get _toDate => _period == _HistoryPeriod.day
      ? _fromDate
      : DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

  @override
  void initState() {
    super.initState();
    _history = _loadHistory();
  }

  Future<List<ShiftRecordModel>> _loadHistory() async {
    _additionalAdminRecords.clear();
    _firstAdminPage = [];
    _adminPage = 1;
    _adminTotalCount = 0;
    _loadMoreError = null;
    if (!widget.isAdmin) return AttendanceService.getMyAttendanceHistory();

    final page = await AttendanceService.getAdminAttendanceHistory(
      fromDate: _fromDate,
      toDate: _toDate,
      page: 1,
    );
    _adminTotalCount = page.totalCount;
    _firstAdminPage = page.records;
    return page.records;
  }

  void _reload() => setState(() => _history = _loadHistory());

  Future<void> _loadMoreAdminRecords() async {
    if (_loadingMore ||
        !widget.isAdmin ||
        _firstAdminPage.length + _additionalAdminRecords.length >=
            _adminTotalCount) {
      return;
    }
    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });
    try {
      final page = await AttendanceService.getAdminAttendanceHistory(
        fromDate: _fromDate,
        toDate: _toDate,
        page: _adminPage + 1,
      );
      if (!mounted) return;
      setState(() {
        _adminPage = page.page;
        _additionalAdminRecords.addAll(page.records);
        _adminTotalCount = page.totalCount;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadMoreError = error.toString().replaceFirst('Exception: ', '');
        _loadingMore = false;
      });
    }
  }

  void _movePeriod(int amount) {
    setState(() {
      _selectedDate = _period == _HistoryPeriod.day
          ? _selectedDate.add(Duration(days: amount))
          : DateTime(_selectedDate.year, _selectedDate.month + amount, 1);
      _history = _loadHistory();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = picked;
      _history = _loadHistory();
    });
  }

  String get _periodLabel => _period == _HistoryPeriod.day
      ? '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}'
      : 'Tháng ${_selectedDate.month}/${_selectedDate.year}';

  bool get _isCurrentPeriod {
    final now = DateTime.now();
    return _period == _HistoryPeriod.day
        ? _selectedDate.year == now.year &&
              _selectedDate.month == now.month &&
              _selectedDate.day == now.day
        : _selectedDate.year == now.year && _selectedDate.month == now.month;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgLightCream,
    appBar: AppBar(
      title: Text(
        widget.isAdmin ? 'Lịch sử chấm công nhân viên' : 'Lịch sử chấm công',
      ),
      backgroundColor: AppColors.bgLightCream,
      foregroundColor: AppColors.textDark,
    ),
    body: Column(
      children: [
        if (widget.isAdmin) _buildAdminFilters(),
        Expanded(
          child: FutureBuilder<List<ShiftRecordModel>>(
            future: _history,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _buildMessage(
                  icon: Icons.cloud_off_outlined,
                  message: snapshot.error.toString().replaceFirst(
                    'Exception: ',
                    '',
                  ),
                  action: TextButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                );
              }
              final records = [...?snapshot.data, ..._additionalAdminRecords];
              if (records.isEmpty) {
                return _buildMessage(
                  icon: Icons.event_busy_outlined,
                  message:
                      'Không có dữ liệu chấm công trong khoảng thời gian này.',
                  action: IconButton(
                    tooltip: 'Tải lại',
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount:
                      records.length +
                      (widget.isAdmin && records.length < _adminTotalCount
                          ? 1
                          : 0),
                  itemBuilder: (context, index) {
                    if (index == records.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Center(
                          child: _loadingMore
                              ? const CircularProgressIndicator()
                              : Column(
                                  children: [
                                    if (_loadMoreError != null)
                                      Text(_loadMoreError!),
                                    TextButton.icon(
                                      onPressed: _loadMoreAdminRecords,
                                      icon: const Icon(Icons.expand_more),
                                      label: Text(
                                        'Tải thêm (${records.length}/$_adminTotalCount)',
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildRecord(records[index]),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _buildAdminFilters() => Container(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    color: Colors.white,
    child: Column(
      children: [
        SegmentedButton<_HistoryPeriod>(
          segments: const [
            ButtonSegment(value: _HistoryPeriod.day, label: Text('Theo ngày')),
            ButtonSegment(
              value: _HistoryPeriod.month,
              label: Text('Theo tháng'),
            ),
          ],
          selected: {_period},
          onSelectionChanged: (value) => setState(() {
            _period = value.first;
            _history = _loadHistory();
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: () => _movePeriod(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(_periodLabel),
              ),
            ),
            IconButton(
              onPressed: _isCurrentPeriod ? null : () => _movePeriod(1),
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              tooltip: 'Tải lại',
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildRecord(ShiftRecordModel record) {
    final adminRecord = record is AdminAttendanceHistoryModel ? record : null;
    final checkOut = record.checkOutAt;
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.access_time, color: AppColors.primaryOrange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    adminRecord?.employeeName ?? record.shiftName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                _statusChip(record.status),
              ],
            ),
            if (adminRecord?.employeeEmail?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(left: 32, top: 2),
                child: Text(
                  adminRecord!.employeeEmail!,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _detail(Icons.calendar_today_outlined, record.shiftDate),
                _detail(Icons.login, 'Vào ${_formatTime(record.checkInAt)}'),
                _detail(
                  Icons.logout,
                  'Ra ${checkOut == null ? 'Chưa ghi nhận' : _formatTime(checkOut)}',
                ),
                if (record.actualHours != null)
                  _detail(
                    Icons.timelapse,
                    '${record.actualHours!.toStringAsFixed(2)} giờ',
                  ),
              ],
            ),
            if (adminRecord != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Mã nhân viên: ${adminRecord.employeeId}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: Colors.grey.shade600),
      const SizedBox(width: 5),
      Text(text, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
    ],
  );

  Widget _statusChip(String status) {
    final active = status.toLowerCase().contains('check');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Đang làm' : 'Hoàn tất',
        style: TextStyle(
          color: active ? Colors.orange.shade800 : Colors.green.shade800,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String message,
    required Widget action,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          action,
        ],
      ),
    ),
  );

  String _formatTime(DateTime dateTime) =>
      '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
}
