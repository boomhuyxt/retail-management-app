import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'core/attendance_service.dart';
import 'theme.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _currentWeekDays = _getWeekDays(_selectedDate);
    _loadAssignedShifts();
  }

  /// Lấy danh sách 7 ngày trong tuần (Từ Thứ 2 đến Chủ Nhật) dựa trên 1 ngày bất kỳ
  List<DateTime> _getWeekDays(DateTime date) {
    final int currentWeekday = date.weekday; // 1: Monday, 7: Sunday
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

  /// Tải danh sách phân công ca làm việc của nhân viên đang đăng nhập
  Future<void> _loadAssignedShifts() async {
    setState(() => _isLoading = true);

    // Gọi API/Service lấy phân công lịch làm việc
    final records = await AttendanceService.getShiftHistory();
    if (!mounted) return;

    // Lọc ra các ca làm việc trùng khớp với ngày được chọn (_selectedDate)
    final formattedSelectedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final filtered = records.where((shift) {
      // Giả định shiftDate có dạng "yyyy-MM-dd" hoặc "dd/MM/yyyy"
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
      // Bỏ SafeArea bao quanh toàn bộ Column, chỉ dùng SafeArea cho phần trên nếu cần
      body: Column(
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
          // Container này sẽ tự động kéo dài tràn ra phía sau Navigation Bar
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
                      // Thêm padding phía dưới cùng cho ListView để item cuối không bị che mất bởi thanh Navigation
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
    );
  }

  /// Card hiển thị từng Ca được phân công
  Widget _buildShiftItemCard(ShiftRecordModel shift) {
    final bool hasCheckOut = shift.checkOutAt != null;
    final bool isWorking = shift.checkOutAt == null;

    Color statusColor = Colors.orange;
    String statusText = 'Chưa vào ca';

    if (hasCheckOut) {
      statusColor = Colors.green;
      statusText = 'Đã hoàn thành';
    } else if (isWorking) {
      statusColor = Colors.blue;
      statusText = 'Đang làm việc';
    }

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
                  color: statusColor.withOpacity(0.12),
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
                'Thời gian: ${DateFormat("HH:mm").format(shift.checkInAt)} - ${shift.checkOutAt != null ? DateFormat("HH:mm").format(shift.checkOutAt!) : "--:--"}',
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