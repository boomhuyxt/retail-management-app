import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'core/attendance_service.dart';
import 'core/auth_service.dart';
import 'theme.dart';
import 'dart:ui';

class ShiftScheduleScreen extends StatefulWidget {
  const ShiftScheduleScreen({super.key});

  @override
  State<ShiftScheduleScreen> createState() => _ShiftScheduleScreenState();
}

class _ShiftScheduleScreenState extends State<ShiftScheduleScreen> {
  late DateTime _selectedDate;
  late List<DateTime> _currentWeekDays;
  bool _isLoading = false;
  List<ShiftRecordModel> _assignedShifts = [];

  bool isAdminOrOwner = false;
  bool _isMenuOpen = false; // Quản lý trạng thái mở/đóng menu

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _selectedDate = DateTime.now();
    _currentWeekDays = _getWeekDays(_selectedDate);
    _loadAssignedShifts();
  }

  /// Kiểm tra vai trò của người dùng hiện tại
  void _checkUserRole() {
    final user = AuthService.currentUser;
    final role = user?.role.toLowerCase() ?? '';
    setState(() {
      isAdminOrOwner = role == 'admin' || role == 'owner' || role == 'chủ cửa hàng';
    });
  }

  /// Lấy danh sách 7 ngày trong tuần (Từ Thứ 2 đến Chủ Nhật)
  List<DateTime> _getWeekDays(DateTime date) {
    final int currentWeekday = date.weekday;
    final DateTime monday = date.subtract(Duration(days: currentWeekday - 1));
    return List.generate(7, (index) => monday.add(Duration(days: index)));
  }

  /// Chuyển tuần (Trước / Sau)
  void _changeWeek(int weekOffset) {
    setState(() {
      final newDate = _selectedDate.add(Duration(days: weekOffset * 7));
      _selectedDate = newDate;
      _currentWeekDays = _getWeekDays(newDate);
    });
    _loadAssignedShifts();
  }

  /// Tải danh sách phân công ca làm việc
  Future<void> _loadAssignedShifts() async {
    setState(() => _isLoading = true);

    final records = await AttendanceService.getShiftHistory();
    if (!mounted) return;

    final formattedSelectedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final filtered = records.where((shift) {
      return shift.shiftDate == formattedSelectedDate ||
          shift.shiftDate == DateFormat('dd/MM/yyyy').format(_selectedDate);
    }).toList();

    setState(() {
      _isLoading = false;
      _assignedShifts = filtered;
    });
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.bgLightCream,
      appBar: AppBar(
        title: const Text(
          'Lịch Phân Ca Làm Việc',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedDate = DateTime.now();
                _currentWeekDays = _getWeekDays(_selectedDate);
              });
              _loadAssignedShifts();
            },
            child: const Text(
              'Hôm nay',
              style: TextStyle(
                color: AppColors.primaryOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          // 1. GIAO DIỆN CHÍNH MÀN HÌNH LỊCH PHÂN CA
          Column(
            children: [
              // --- THANH CHỌN TUẦN & THÁNG ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _changeWeek(-1),
                    ),
                    Text(
                      'Tháng ${DateFormat('MM/yyyy').format(_selectedDate)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _changeWeek(1),
                    ),
                  ],
                ),
              ),

              // --- THANH HIỂN THỊ 7 NGÀY TRONG TUẦN ---
              Container(
                height: 85,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _currentWeekDays.map((day) {
                    final bool isSelected = _isSameDay(day, _selectedDate);
                    final bool isToday = _isSameDay(day, today);

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDate = day;
                          });
                          _loadAssignedShifts();
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryOrange
                                : (isToday
                                ? AppColors.primaryOrange.withOpacity(0.15)
                                : Colors.white),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryOrange
                                  : (isToday
                                  ? AppColors.primaryOrange
                                  : Colors.grey.shade300),
                              width: isToday || isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _getVietnameseWeekday(day.weekday),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : (isToday
                                      ? AppColors.primaryOrange
                                      : Colors.grey.shade600),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              // --- BẢNG DANH SÁCH CA LÀM VIỆC ---
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ca làm việc: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 20, color: Colors.grey),
                            onPressed: _loadAssignedShifts,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: _isLoading
                            ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryOrange,
                          ),
                        )
                            : _assignedShifts.isEmpty
                            ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event_available,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Không có ca làm việc nào được phân công',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                            : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 90),
                          itemCount: _assignedShifts.length,
                          itemBuilder: (context, index) {
                            final shift = _assignedShifts[index];
                            return _buildShiftItemCard(shift);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 2. LỚP PHỦ MỜ (BLUR BACKGROUND) KHI MỞ MENU (CHỈ CHO ADMIN / OWNER)
          if (isAdminOrOwner && _isMenuOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isMenuOpen = false;
                  });
                },
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),

            // 3. MENU TRƯỢT NGANG NẰM BÊN TRÁI NÚT CHÍNH (KHÔNG BỊ OVERFLOW)
            Positioned(
              right: 80,
              bottom: 60,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isMenuOpen ? 1.0 : 0.0,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          onTap: () {
                            setState(() => _isMenuOpen = false);
                            _showAddShiftDialog(context);
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_circle_outline, color: AppColors.primaryOrange, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Thêm ca làm mới',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 1, thickness: 0.5),
                        InkWell(
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                          onTap: () {
                            setState(() => _isMenuOpen = false);
                            _showEditShiftDialog(context);
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Chỉnh sửa ca làm',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),

      // 4. FLOATING ACTION BUTTON DUY NHẤT (CHỈ HIỂN THỊ KHI LÀ ADMIN/OWNER)
      floatingActionButton: isAdminOrOwner
          ? Padding(
        padding: const EdgeInsets.only(bottom: 60.0),
        child: AnimatedRotation(
          turns: _isMenuOpen ? 0.125 : 0.0, // Xoay 45 độ thành dấu x
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: FloatingActionButton(
            onPressed: () {
              setState(() {
                _isMenuOpen = !_isMenuOpen;
              });
            },
            backgroundColor: AppColors.primaryOrange,
            shape: const CircleBorder(),
            elevation: 4,
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      )
          : null,
    );
  }

  void _showAddShiftDialog(BuildContext context) {
    final nameController = TextEditingController();
    final idController = TextEditingController();
    String selectedShift = 'Sáng';
    final List<String> shiftOptions = ['Sáng', 'Trưa', 'Chiều', 'Đêm'];

    TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> selectTime(bool isStart) async {
              final TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: isStart ? startTime : endTime,
                builder: (BuildContext context, Widget? child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: AppColors.primaryOrange,
                        onPrimary: Colors.white,
                        onSurface: AppColors.textDark,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setDialogState(() {
                  if (isStart) {
                    startTime = picked;
                  } else {
                    endTime = picked;
                  }
                });
              }
            }

            String formatTimeOfDay(TimeOfDay time) {
              final hour = time.hour.toString().padLeft(2, '0');
              final minute = time.minute.toString().padLeft(2, '0');
              return '$hour:$minute';
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Thêm ca làm mới',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên nhân viên',
                        hintText: 'Nhập tên nhân viên',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: idController,
                      decoration: const InputDecoration(
                        labelText: 'Mã số nhân viên',
                        hintText: 'Nhập mã số (VD: NV001)',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedShift,
                      decoration: const InputDecoration(
                        labelText: 'Ca làm việc',
                        prefixIcon: Icon(Icons.work_history_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: shiftOptions.map((String shift) {
                        return DropdownMenuItem<String>(
                          value: shift,
                          child: Text(shift),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setDialogState(() {
                            selectedShift = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Thời gian làm việc',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => selectTime(true),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Bắt đầu',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        formatTimeOfDay(startTime),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Icon(
                                    Icons.access_time,
                                    size: 20,
                                    color: AppColors.primaryOrange,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => selectTime(false),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Kết thúc',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        formatTimeOfDay(endTime),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Icon(
                                    Icons.access_time,
                                    size: 20,
                                    color: AppColors.primaryOrange,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    final String name = nameController.text.trim();
                    final String empId = idController.text.trim();

                    if (name.isEmpty || empId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng điền đầy đủ thông tin!'),
                        ),
                      );
                      return;
                    }

                    final startMinutes = startTime.hour * 60 + startTime.minute;
                    final endMinutes = endTime.hour * 60 + endTime.minute;

                    if (endMinutes <= startMinutes) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Thời gian kết thúc phải lớn hơn thời gian bắt đầu!'),
                        ),
                      );
                      return;
                    }

                    Navigator.of(dialogContext).pop();
                    setState(() {
                      _loadAssignedShifts();
                    });
                  },
                  child: const Text(
                    'Thêm ca',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditShiftDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Chỉnh sửa ca làm',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Chọn danh sách ca làm cần chỉnh sửa hoặc quản lý ca làm hiện tại.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  /// Card hiển thị từng Ca được phân công
  Widget _buildShiftItemCard(ShiftRecordModel shift) {
    final bool hasCheckOut = shift.checkOutAt != null;
    final bool isWorking = shift.checkInAt != null && shift.checkOutAt == null;

    Color statusColor = Colors.orange;
    String statusText = 'Chưa vào ca';

    if (hasCheckOut) {
      statusColor = Colors.green;
      statusText = 'Đã hoàn thành';
    } else if (isWorking) {
      statusColor = Colors.blue;
      statusText = 'Đang làm việc';
    }

    final String checkInStr = shift.checkInAt != null
        ? DateFormat("HH:mm").format(shift.checkInAt!)
        : "--:--";
    final String checkOutStr = shift.checkOutAt != null
        ? DateFormat("HH:mm").format(shift.checkOutAt!)
        : "--:--";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgLightCream.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                shift.shiftName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time_filled, size: 16, color: AppColors.primaryOrange),
              const SizedBox(width: 6),
              Text(
                'Thời gian: $checkInStr - $checkOutStr',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.work_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                'Tổng số giờ: ${shift.actualHours ?? 0} giờ',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Chuyển đổi thứ từ số sang chuỗi tiếng Việt gọn
  String _getVietnameseWeekday(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'T2';
      case DateTime.tuesday:
        return 'T3';
      case DateTime.wednesday:
        return 'T4';
      case DateTime.thursday:
        return 'T5';
      case DateTime.friday:
        return 'T6';
      case DateTime.saturday:
        return 'T7';
      case DateTime.sunday:
        return 'CN';
      default:
        return '';
    }
  }
}