import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'core/api_config.dart';
import 'core/auth_service.dart';
import 'core/schedule_service.dart';
import 'theme.dart';
import 'widgets/wheel_time_picker.dart';

class _OverlapStatus {
  final List<ScheduleShift> overlappingShifts;
  final bool hasSelfConflict;
  final ScheduleShift? conflictingShift;

  const _OverlapStatus({
    required this.overlappingShifts,
    required this.hasSelfConflict,
    this.conflictingShift,
  });
}

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

  // Dành cho Quản lý / Chủ cửa hàng
  int? _filterEmployeeId;
  List<StaffEmployee> _employees = [];
  List<ShiftTemplateModel> _templates = [];

  bool get _isManager {
    final role = AuthService.currentUser?.role;
    return role == 'Admin' || role == 'Manager';
  }

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
      final items = await (widget.loadSchedule != null
          ? widget.loadSchedule!(from, from.add(const Duration(days: 6)))
          : ScheduleService.getSchedule(
              from,
              from.add(const Duration(days: 6)),
              employeeId: _filterEmployeeId,
            ));
      if (!mounted || request != _request) return;
      setState(() {
        _shifts = items;
        _loading = false;
      });

      if (_isManager && _employees.isEmpty) {
        _loadManagerMetadata();
      }
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadManagerMetadata() async {
    try {
      final emps = await ScheduleService.getEmployees();
      final tpls = await ScheduleService.getTemplates();
      if (!mounted) return;
      setState(() {
        _employees = emps;
        _templates = tpls;
      });
    } catch (_) {
      // Ignore background metadata error; will retry when opening sheet
    }
  }

  void _move(int weeks) {
    setState(
      () => _selectedDate = _selectedDate.add(Duration(days: weeks * 7)),
    );
    _load();
  }

  /// Tính toán số lượng nhân viên đang trùng khung giờ & kiểm tra xung đột cá nhân
  _OverlapStatus _computeOverlap({
    required DateTime targetDate,
    required TimeOfDay start,
    required TimeOfDay end,
    required bool isOvernight,
    required int? employeeId,
  }) {
    final pStart = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      start.hour,
      start.minute,
    );
    final pEnd = isOvernight
        ? DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day + 1,
            end.hour,
            end.minute,
          )
        : DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day,
            end.hour,
            end.minute,
          );

    final overlapping = <ScheduleShift>[];
    bool selfConflict = false;
    ScheduleShift? selfShift;

    for (final s in _shifts) {
      if (s.status == 'Cancelled') continue;
      final dateParts = s.date.split('-');
      if (dateParts.length != 3) continue;
      final y = int.tryParse(dateParts[0]) ?? 0;
      final m = int.tryParse(dateParts[1]) ?? 0;
      final d = int.tryParse(dateParts[2]) ?? 0;

      final sTimeParts = s.startTime.split(':');
      final eTimeParts = s.endTime.split(':');
      if (sTimeParts.isEmpty || eTimeParts.isEmpty) continue;

      final sh = int.tryParse(sTimeParts[0]) ?? 0;
      final sm = int.tryParse(sTimeParts.length > 1 ? sTimeParts[1] : '0') ?? 0;
      final eh = int.tryParse(eTimeParts[0]) ?? 0;
      final em = int.tryParse(eTimeParts.length > 1 ? eTimeParts[1] : '0') ?? 0;

      final sStart = DateTime(y, m, d, sh, sm);
      final sEnd = s.isOvernight
          ? DateTime(y, m, d + 1, eh, em)
          : DateTime(y, m, d, eh, em);

      // Điều kiện trùng khoảng thời gian [start, end)
      if (sStart.isBefore(pEnd) && sEnd.isAfter(pStart)) {
        if (employeeId != null && s.employeeId == employeeId) {
          selfConflict = true;
          selfShift = s;
        } else {
          // Tránh trùng lặp nhân viên trong danh sách ca đồng thời
          if (!overlapping.any((o) => o.employeeId == s.employeeId)) {
            overlapping.add(s);
          }
        }
      }
    }

    return _OverlapStatus(
      overlappingShifts: overlapping,
      hasSelfConflict: selfConflict,
      conflictingShift: selfShift,
    );
  }

  /// Mở BottomSheet phân ca mới cho nhân viên (Dành cho Quản lý / Chủ shop)
  void _openAssignShiftSheet() async {
    if (_employees.isEmpty || _templates.isEmpty) {
      try {
        final emps = await ScheduleService.getEmployees();
        final tpls = await ScheduleService.getTemplates();
        if (mounted) {
          setState(() {
            _employees = emps;
            _templates = tpls;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
          );
        }
      }
    }

    int? selectedEmpId = _employees.isNotEmpty ? _employees.first.id : null;
    int? selectedTemplateId;
    DateTime sheetDate = _selectedDate;
    TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);
    bool isOvernight = false;
    final noteController = TextEditingController();
    final customNameController = TextEditingController(text: 'Ca làm');
    bool isSubmitting = false;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final overlap = _computeOverlap(
            targetDate: sheetDate,
            start: startTime,
            end: endTime,
            isOvernight: isOvernight,
            employeeId: selectedEmpId,
          );

          final startStr =
              '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
          final endStr =
              '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              top: 16,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thanh gạt
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tiêu đề
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Phân ca làm việc mới',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 1. Chọn Nhân viên
                    const Text(
                      'Nhân viên nhận ca *',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: selectedEmpId,
                          hint: const Text('-- Chọn nhân viên --'),
                          items: _employees.map((emp) {
                            return DropdownMenuItem<int>(
                              value: emp.id,
                              child: Text(
                                '${emp.displayName} (${emp.code})${emp.departmentName != null ? ' - ${emp.departmentName}' : ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setModalState(() => selectedEmpId = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Ngày làm việc
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ngày làm việc *',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: modalCtx,
                                    initialDate: sheetDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) {
                                    setModalState(() => sheetDate = picked);
                                  }
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: AppColors.primaryOrange,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat('dd/MM/yyyy').format(sheetDate),
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Chọn ca mẫu
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Mẫu ca (tùy chọn)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int?>(
                                    isExpanded: true,
                                    value: selectedTemplateId,
                                    hint: const Text('Tùy chỉnh', style: TextStyle(fontSize: 13)),
                                    items: [
                                      const DropdownMenuItem<int?>(
                                        value: null,
                                        child: Text('Tùy chỉnh giờ', style: TextStyle(fontSize: 13)),
                                      ),
                                      ..._templates.map((tpl) {
                                        return DropdownMenuItem<int?>(
                                          value: tpl.id,
                                          child: Text(
                                            '${tpl.name} (${tpl.startTime}-${tpl.endTime})',
                                            style: const TextStyle(fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }),
                                    ],
                                    onChanged: (val) {
                                      setModalState(() {
                                        selectedTemplateId = val;
                                        if (val != null) {
                                          final tpl = _templates.firstWhere((t) => t.id == val);
                                          final sParts = tpl.startTime.split(':');
                                          final eParts = tpl.endTime.split(':');
                                          startTime = TimeOfDay(
                                            hour: int.tryParse(sParts[0]) ?? 8,
                                            minute: int.tryParse(sParts.length > 1 ? sParts[1] : '0') ?? 0,
                                          );
                                          endTime = TimeOfDay(
                                            hour: int.tryParse(eParts[0]) ?? 17,
                                            minute: int.tryParse(eParts.length > 1 ? eParts[1] : '0') ?? 0,
                                          );
                                          isOvernight = tpl.isOvernight;
                                          customNameController.text = tpl.name;
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 3. Khung giờ làm việc (Chuẩn 24H - Wheel Picker)
                    const Text(
                      'Thời gian ca làm (Chuẩn 24 giờ quốc tế 00:00 - 23:59) *',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Giờ bắt đầu
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await show24HourWheelTimePicker(
                                context: modalCtx,
                                initialTime: startTime,
                                title: 'Chọn giờ bắt đầu (24H)',
                              );
                              if (picked != null) {
                                setModalState(() {
                                  startTime = picked;
                                  selectedTemplateId = null;
                                  if (endTime.hour < startTime.hour && !isOvernight) {
                                    isOvernight = true;
                                  }
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.bgLightCream,
                                border: Border.all(
                                  color: AppColors.primaryOrange.withValues(alpha: 0.5),
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Bắt đầu',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        size: 18,
                                        color: AppColors.primaryOrange,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        startStr,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward, color: Colors.grey, size: 20),
                        ),
                        // Giờ kết thúc
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await show24HourWheelTimePicker(
                                context: modalCtx,
                                initialTime: endTime,
                                title: 'Chọn giờ kết thúc (24H)',
                              );
                              if (picked != null) {
                                setModalState(() {
                                  endTime = picked;
                                  selectedTemplateId = null;
                                  if (endTime.hour < startTime.hour && !isOvernight) {
                                    isOvernight = true;
                                  }
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.bgLightCream,
                                border: Border.all(
                                  color: AppColors.primaryOrange.withValues(alpha: 0.5),
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Kết thúc',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time_filled,
                                        size: 18,
                                        color: AppColors.primaryOrange,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        endStr,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // 4. Checkbox ca qua đêm (người quản lý tự tích chọn)
                    CheckboxListTile(
                      title: const Text(
                        'Kết thúc vào ngày hôm sau (Ca qua đêm)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Tích chọn cho các ca làm việc kéo dài qua 00:00 (Ví dụ: 22:00 – 06:00)',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      value: isOvernight,
                      activeColor: AppColors.primaryOrange,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) {
                        setModalState(() => isOvernight = val ?? false);
                      },
                    ),

                    // Cảnh báo nếu giờ kết thúc nhỏ hơn bắt đầu mà chưa tích qua đêm
                    if (!isOvernight &&
                        (endTime.hour < startTime.hour ||
                            (endTime.hour == startTime.hour && endTime.minute < startTime.minute)))
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber.shade900),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Giờ kết thúc ($endStr) nhỏ hơn giờ bắt đầu ($startStr). Hãy tích chọn ô ca qua đêm bên trên.',
                                style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // 5. Vị trí nhỏ thông báo số nhân viên đã sắp ca trong khung giờ này
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: overlap.hasSelfConflict
                            ? Colors.red.shade50
                            : overlap.overlappingShifts.isNotEmpty
                            ? Colors.blue.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: overlap.hasSelfConflict
                              ? Colors.red.shade300
                              : overlap.overlappingShifts.isNotEmpty
                              ? Colors.blue.shade300
                              : Colors.green.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (overlap.hasSelfConflict) ...[
                            Row(
                              children: [
                                Icon(Icons.error_outline, size: 18, color: Colors.red.shade800),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Xung đột: Nhân viên này đã có ca làm trùng giờ!',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Nhân viên đã có ca "${overlap.conflictingShift?.name}" (${overlap.conflictingShift?.startTime} – ${overlap.conflictingShift?.endTime}). Vui lòng chọn khung giờ khác cho nhân viên này.',
                              style: TextStyle(fontSize: 11, color: Colors.red.shade800),
                            ),
                          ] else if (overlap.overlappingShifts.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(Icons.people, size: 18, color: Colors.blue.shade800),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Có ${overlap.overlappingShifts.length} nhân viên khác làm trong khung giờ này:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: overlap.overlappingShifts.map((s) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Text(
                                    '${s.employeeName ?? 'NV-${s.employeeId}'} (${s.startTime}–${s.endTime})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '✓ Hệ thống cho phép nhiều nhân viên cùng làm việc đồng thời.',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Icon(Icons.check_circle_outline, size: 18, color: Colors.green.shade800),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Khung giờ trống: Chưa có nhân viên nào làm việc trong khoảng này.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // 6. Tên ca làm
                    const Text(
                      'Tên ca làm việc',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: customNameController,
                      decoration: const InputDecoration(
                        hintText: 'VD: Ca sáng, Ca tối, Ca phụ',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 7. Ghi chú
                    const Text(
                      'Ghi chú (tùy chọn)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Nhập ghi chú cho nhân viên (nếu có)...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Nút xác nhận phân ca
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isSubmitting || overlap.hasSelfConflict || selectedEmpId == null
                            ? null
                            : () async {
                                setModalState(() => isSubmitting = true);
                                try {
                                  final dateStr = scheduleDate(sheetDate);
                                  await ScheduleService.assignShift(
                                    employeeId: selectedEmpId!,
                                    shiftDate: dateStr,
                                    shiftTemplateId: selectedTemplateId,
                                    customShiftName: customNameController.text.trim().isNotEmpty
                                        ? customNameController.text.trim()
                                        : 'Ca làm',
                                    customStartTime: '$startStr:00',
                                    customEndTime: '$endStr:00',
                                    isOvernight: isOvernight,
                                    note: noteController.text.trim().isNotEmpty
                                        ? noteController.text.trim()
                                        : null,
                                  );

                                  if (!modalCtx.mounted) return;
                                  Navigator.pop(modalCtx);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Phân ca làm việc thành công!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  _load();
                                } catch (e) {
                                  if (!modalCtx.mounted) return;
                                  setModalState(() => isSubmitting = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Lỗi phân ca: ${e.toString().replaceFirst('Exception: ', '')}',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Xác nhận phân ca',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Xác nhận và hủy ca làm việc (Dành cho Quản lý)
  Future<void> _confirmDeleteShift(ScheduleShift shift) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy phân ca làm việc'),
        content: Text(
          'Bạn có chắc chắn muốn hủy phân ca "${shift.name}" (${shift.startTime} – ${shift.endTime}) '
          'của nhân viên ${shift.employeeName ?? 'NV-${shift.employeeId}'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hủy ca', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ScheduleService.deleteShift(shift.assignmentId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã hủy phân ca thành công.'),
            backgroundColor: Colors.green,
          ),
        );
        _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
        title: Text(_isManager ? 'Lịch làm việc & Phân ca' : 'Lịch làm việc'),
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
      floatingActionButton: _isManager
          ? FloatingActionButton.extended(
              onPressed: _openAssignShiftSheet,
              backgroundColor: AppColors.primaryOrange,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Phân ca mới',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // Bộ lọc nhân viên cho Quản lý
            if (_isManager && _employees.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list, size: 18, color: AppColors.primaryOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          isExpanded: true,
                          value: _filterEmployeeId,
                          hint: const Text(
                            'Xem tất cả nhân viên trong cửa hàng',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text(
                                'Tất cả nhân viên',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                            ..._employees.map((emp) {
                              return DropdownMenuItem<int?>(
                                value: emp.id,
                                child: Text(
                                  '${emp.displayName} (${emp.code})',
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setState(() => _filterEmployeeId = val);
                            _load();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Chuyển tuần
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

            // Các ngày trong tuần
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

            // Tiêu đề ngày chọn
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

            // Danh sách ca làm việc
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
                            ? [
                                Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    children: [
                                      const Text(
                                        'Chưa được phân ca trong ngày này.',
                                        textAlign: TextAlign.center,
                                      ),
                                      if (_isManager) ...[
                                        const SizedBox(height: 12),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primaryOrange,
                                          ),
                                          onPressed: _openAssignShiftSheet,
                                          icon: const Icon(Icons.add, color: Colors.white),
                                          label: const Text(
                                            'Phân ca ngay',
                                            style: TextStyle(color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ],
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shift.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      // Hiển thị tên nhân viên nếu là Quản lý hoặc có dữ liệu nhân viên
                      if (shift.employeeName != null || _isManager)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.person, size: 14, color: Colors.grey.shade700),
                              const SizedBox(width: 4),
                              Text(
                                shift.employeeName ?? 'NV-${shift.employeeId}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              if (shift.departmentName != null) ...[
                                const Text(' · ', style: TextStyle(color: Colors.grey)),
                                Text(
                                  shift.departmentName!,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Nút hủy ca cho Quản lý
                if (_isManager && shift.status != 'Cancelled')
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    tooltip: 'Hủy phân ca',
                    onPressed: () => _confirmDeleteShift(shift),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${shift.startTime} – ${shift.endTime}${shift.isOvernight ? ' (kết thúc ngày hôm sau)' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (shift.checkOutAt != null ? Colors.green : color).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                shift.statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: shift.checkOutAt != null ? Colors.green.shade700 : color,
                ),
              ),
            ),
            if (shift.note?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  shift.note!,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
