import 'dart:math';
import 'package:flutter/material.dart';
import 'core/auth_service.dart';
import 'core/leave_request_service.dart';
import 'core/schedule_service.dart';

class LeaveRequestsScreen extends StatefulWidget {
  const LeaveRequestsScreen({super.key});
  @override
  State<LeaveRequestsScreen> createState() => _LeaveRequestsScreenState();
}

class _LeaveRequestsScreenState extends State<LeaveRequestsScreen> {
  List<LeaveRequestItem> _items = [];
  bool _busy = false;
  String? _error;
  int _page = 1;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final items = await LeaveRequestService.getMyLeaveRequests(
        status: _status,
        page: _page,
        pageSize: 20,
      );
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _detail(LeaveRequestItem item) async {
    try {
      final detail = await LeaveRequestService.getDetail(item.id);
      if (!mounted) return;
      final current = LeaveRequestItem.fromJson(
        detail['request'] as Map<String, dynamic>,
      );
      final cancel = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Đơn #${current.id} · ${current.statusLabel}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(current.requestedPeriod),
                Text('${current.reasonLabel}\n${current.reason}'),
                Text('Phút nghỉ theo lịch: ${current.scheduledLeaveMinutes}'),
                const Text('Dữ liệu lương cần được đối soát theo chính sách.'),
                if (current.reviewNote != null)
                  Text('Ghi chú duyệt: ${current.reviewNote}'),
                if (current.rejectionReason != null)
                  Text('Từ chối: ${current.rejectionReason}'),
                if (current.revocationReason != null)
                  Text('Thu hồi: ${current.revocationReason}'),
                const Divider(),
                for (final h in (detail['history'] as List? ?? []))
                  Text(
                    '${h['action']} · ${h['actorName']}\n${h['note'] ?? ''}',
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Đóng'),
            ),
            if (current.status == 'Pending')
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Hủy đơn này'),
              ),
          ],
        ),
      );
      if (cancel == true) {
        await LeaveRequestService.cancel(current.id, current.version);
        if (mounted) await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Đơn nghỉ phép'),
      actions: [
        IconButton(
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () async {
        final created = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const CreateLeaveScreen()),
        );
        if (created == true && mounted) {
          _page = 1;
          await _load();
        }
      },
      label: const Text('Tạo đơn'),
      icon: const Icon(Icons.add),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: DropdownButtonFormField<String>(
            initialValue: _status ?? '',
            decoration: const InputDecoration(labelText: 'Trạng thái'),
            items: const [
              DropdownMenuItem(value: '', child: Text('Tất cả')),
              DropdownMenuItem(value: 'Pending', child: Text('Chờ duyệt')),
              DropdownMenuItem(value: 'Approved', child: Text('Đã duyệt')),
              DropdownMenuItem(value: 'Rejected', child: Text('Từ chối')),
              DropdownMenuItem(value: 'Cancelled', child: Text('Đã hủy')),
              DropdownMenuItem(value: 'Revoked', child: Text('Đã thu hồi')),
            ],
            onChanged: _busy
                ? null
                : (v) {
                    _status = v == '' ? null : v;
                    _page = 1;
                    _load();
                  },
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                if (!_busy && _items.isEmpty)
                  const ListTile(title: Text('Chưa có đơn trong trang này.')),
                for (final item in _items)
                  ListTile(
                    title: Text(item.requestedPeriod),
                    subtitle: Text('${item.reasonLabel} · ${item.statusLabel}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _detail(item),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _busy || _page == 1
                          ? null
                          : () {
                              _page--;
                              _load();
                            },
                      child: const Text('Trước'),
                    ),
                    Text('Trang $_page'),
                    TextButton(
                      onPressed: _busy || _items.length < 20
                          ? null
                          : () {
                              _page++;
                              _load();
                            },
                      child: const Text('Tiếp'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class CreateLeaveScreen extends StatefulWidget {
  const CreateLeaveScreen({super.key});
  @override
  State<CreateLeaveScreen> createState() => _CreateLeaveScreenState();
}

class _CreateLeaveScreenState extends State<CreateLeaveScreen> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final _lateReason = TextEditingController();
  String _unit = 'Day', _reasonCode = 'Personal';
  DateTime _start = scheduleToday().add(const Duration(days: 1));
  DateTime _end = scheduleToday().add(const Duration(days: 2));
  bool _emergency = false, _busy = false;
  String? _error;
  List<ScheduleShift> _shifts = [];
  int? _assignment;
  LeavePreviewModel? _preview;
  Map<String, dynamic>? _pendingCommand;
  String? _key;

  @override
  void dispose() {
    _reason.dispose();
    _lateReason.dispose();
    super.dispose();
  }

  void _invalidate() {
    _preview = null;
    _pendingCommand = null;
    _key = null;
  }

  Future<void> _loadShifts() async {
    setState(() {
      _busy = true;
      _error = null;
      _shifts = [];
      _assignment = null;
    });
    try {
      final shifts = await ScheduleService.getSchedule(
        _start,
        _start,
        employeeId: AuthService.currentUser?.id,
      );
      if (mounted)
        setState(
          () => _shifts = shifts
              .where((s) => s.status != 'Cancelled' && !s.isOnLeave)
              .toList(),
        );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(bool end) async {
    final date = await showDatePicker(
      context: context,
      initialDate: end ? _end : _start,
      firstDate: scheduleToday().subtract(const Duration(days: 30)),
      lastDate: DateTime(scheduleToday().year + 3),
    );
    if (date == null || !mounted) return;
    setState(() {
      if (end) {
        _end = date;
      } else {
        _start = date;
      }
      _invalidate();
    });
    if (_unit == 'Shift') await _loadShifts();
  }

  Map<String, dynamic> _input() => {
    'unit': _unit,
    'reasonCode': _reasonCode,
    'reason': _reason.text.trim(),
    'isEmergency': _emergency,
    if (_unit == 'Shift') 'shiftAssignmentId': _assignment,
    if (_unit == 'Day') 'date': scheduleDate(_start),
    if (_unit == 'DateRange') ...{
      'startDate': scheduleDate(_start),
      'endDate': scheduleDate(_end),
    },
    if (_emergency && _lateReason.text.trim().isNotEmpty)
      'lateSubmissionReason': _lateReason.text.trim(),
  };

  Future<void> _previewRequest() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    if (_unit == 'Shift' && _assignment == null) {
      setState(() => _error = 'Chọn ca muốn nghỉ.');
      return;
    }
    if (_unit == 'DateRange' && !_end.isAfter(_start)) {
      setState(() => _error = 'Ngày kết thúc phải sau ngày bắt đầu.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _invalidate();
    });
    try {
      final input = _input();
      final preview = await LeaveRequestService.preview(input);
      if (!mounted) {
        return;
      }
      setState(() {
        _preview = preview;
        _pendingCommand = {...input, 'previewToken': preview.previewToken};
        final r = Random.secure();
        final bytes = List<int>.generate(16, (_) => r.nextInt(256));
        bytes[6] = (bytes[6] & 15) | 64;
        bytes[8] = (bytes[8] & 63) | 128;
        final hex = bytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        _key =
            '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_pendingCommand == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await LeaveRequestService.create(_pendingCommand!, idempotencyKey: _key);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      // Preserve the key and exact command on timeout, so a retry cannot duplicate the request.
      if (mounted)
        setState(
          () => _error =
              '$e\nCó thể gửi lại với cùng nội dung. Nếu lịch đã thay đổi, hãy xem trước lại.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tạo đơn nghỉ phép')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_busy) const LinearProgressIndicator(),
          DropdownButtonFormField<String>(
            initialValue: _unit,
            decoration: const InputDecoration(labelText: 'Thời gian nghỉ'),
            items: const [
              DropdownMenuItem(value: 'Shift', child: Text('Một ca')),
              DropdownMenuItem(value: 'Day', child: Text('Một ngày')),
              DropdownMenuItem(value: 'DateRange', child: Text('Nhiều ngày')),
            ],
            onChanged: _busy
                ? null
                : (v) {
                    setState(() {
                      _unit = v!;
                      _invalidate();
                    });
                    if (v == 'Shift') _loadShifts();
                  },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${_unit == 'DateRange' ? 'Từ ngày' : 'Ngày'}: ${scheduleDate(_start)}',
            ),
            trailing: const Icon(Icons.calendar_month),
            onTap: _busy ? null : () => _pick(false),
          ),
          if (_unit == 'DateRange')
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Đến ngày: ${scheduleDate(_end)}'),
              trailing: const Icon(Icons.calendar_month),
              onTap: _busy ? null : () => _pick(true),
            ),
          if (_unit == 'Shift')
            DropdownButtonFormField<int>(
              key: ValueKey('${scheduleDate(_start)}-${_shifts.length}'),
              initialValue: _assignment,
              decoration: const InputDecoration(labelText: 'Ca của bạn'),
              items: _shifts
                  .map(
                    (s) => DropdownMenuItem(
                      value: s.assignmentId,
                      child: Text(
                        '${s.name} ${s.startTime}–${s.endTime}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (v) => setState(() {
                      _assignment = v;
                      _invalidate();
                    }),
            ),
          if (_unit == 'Shift' && _shifts.isEmpty && !_busy)
            const Text(
              'Không có ca khả dụng. Chọn ngày khác hoặc xin nghỉ nguyên ngày.',
            ),
          DropdownButtonFormField<String>(
            initialValue: _reasonCode,
            decoration: const InputDecoration(labelText: 'Lý do'),
            items: const [
              DropdownMenuItem(value: 'Personal', child: Text('Việc cá nhân')),
              DropdownMenuItem(
                value: 'FamilyEmergency',
                child: Text('Việc gia đình'),
              ),
              DropdownMenuItem(value: 'Sickness', child: Text('Ốm đau')),
              DropdownMenuItem(value: 'Maternity', child: Text('Thai sản')),
              DropdownMenuItem(value: 'Other', child: Text('Khác')),
            ],
            onChanged: _busy
                ? null
                : (v) => setState(() {
                    _reasonCode = v!;
                    _invalidate();
                  }),
          ),
          TextFormField(
            controller: _reason,
            enabled: !_busy,
            maxLength: 2000,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Giải trình'),
            validator: (v) =>
                (v?.trim().length ?? 0) < 10 ? 'Nhập ít nhất 10 ký tự.' : null,
            onChanged: (_) => setState(_invalidate),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Khẩn cấp / nộp bổ sung'),
            value: _emergency,
            onChanged: _busy
                ? null
                : (v) => setState(() {
                    _emergency = v;
                    _invalidate();
                  }),
          ),
          if (_emergency)
            TextFormField(
              controller: _lateReason,
              enabled: !_busy,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Giải thích nộp bổ sung',
              ),
              onChanged: (_) => setState(_invalidate),
            ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          OutlinedButton(
            onPressed: _busy ? null : _previewRequest,
            child: const Text('Xem trước tác động'),
          ),
          if (_preview != null) ...[
            Text(
              _preview!.requestedPeriod,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final interval in _preview!.effectiveIntervals)
              Text('${interval['startLocal']} → ${interval['endLocal']}'),
            for (final shift in _preview!.affectedAssignments)
              Text(
                '${shift['shiftName']} · ${shift['shiftDate']} · ${shift['startTime']}–${shift['endTime']}',
              ),
            Text(
              '${_preview!.scheduledLeaveMinutes} phút theo lịch. Quyền lợi lương cần đối soát.',
            ),
            for (final warning in _preview!.warnings)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(warning),
              ),
            if (_preview!.hasConflict)
              Text(
                _preview!.conflictReason ?? 'Có xung đột',
                style: const TextStyle(color: Colors.red),
              ),
            FilledButton(
              onPressed: _busy || _preview!.hasConflict ? null : _submit,
              child: const Text('Gửi đơn chờ Admin duyệt'),
            ),
          ],
        ],
      ),
    ),
  );
}
