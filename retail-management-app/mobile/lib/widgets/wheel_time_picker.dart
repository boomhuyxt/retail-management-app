import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme.dart';

/// Modal cuộn bánh xe (Cupertino Wheel Picker) chọn giờ chuẩn quốc tế 24 giờ (00:00 - 23:59)
Future<TimeOfDay?> show24HourWheelTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String title = 'Chọn giờ (Chuẩn 24H)',
}) async {
  return await showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _WheelTimePickerSheet(
      initialTime: initialTime,
      title: title,
    ),
  );
}

class _WheelTimePickerSheet extends StatefulWidget {
  final TimeOfDay initialTime;
  final String title;

  const _WheelTimePickerSheet({
    required this.initialTime,
    required this.title,
  });

  @override
  State<_WheelTimePickerSheet> createState() => _WheelTimePickerSheetState();
}

class _WheelTimePickerSheetState extends State<_WheelTimePickerSheet> {
  late int _selectedHour;
  late int _selectedMinute;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour;
    _selectedMinute = widget.initialTime.minute;
    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController = FixedExtentScrollController(initialItem: _selectedMinute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _setMinute(int minute) {
    setState(() => _selectedMinute = minute);
    _minuteController.animateToItem(
      minute,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hourStr = _selectedHour.toString().padLeft(2, '0');
    final minuteStr = _selectedMinute.toString().padLeft(2, '0');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thanh gạt modal
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // Tiêu đề & Nút đóng
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Màn hình số hiển thị giờ đã chọn (Chuẩn 24 giờ quốc tế)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.bgLightCream,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hourStr,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      ':',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  Text(
                    minuteStr,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '24H',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Nhãn cột Giờ & Phút
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      'GIỜ (0 - 23)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'PHÚT (00 - 59)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 2 Bánh xe cuộn (CupertinoPicker)
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  // Bánh xe Giờ (0 - 23)
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: _hourController,
                      itemExtent: 44,
                      selectionOverlay: Container(
                        decoration: BoxDecoration(
                          border: Border.symmetric(
                            horizontal: BorderSide(
                              color: AppColors.primaryOrange.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      onSelectedItemChanged: (index) {
                        setState(() => _selectedHour = index);
                      },
                      children: List.generate(24, (i) {
                        final isSel = i == _selectedHour;
                        return Center(
                          child: Text(
                            i.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: isSel ? 24 : 18,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              color: isSel ? AppColors.primaryOrange : Colors.black87,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  const Text(
                    ':',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),

                  // Bánh xe Phút (0 - 59)
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: _minuteController,
                      itemExtent: 44,
                      selectionOverlay: Container(
                        decoration: BoxDecoration(
                          border: Border.symmetric(
                            horizontal: BorderSide(
                              color: AppColors.primaryOrange.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      onSelectedItemChanged: (index) {
                        setState(() => _selectedMinute = index);
                      },
                      children: List.generate(60, (i) {
                        final isSel = i == _selectedMinute;
                        return Center(
                          child: Text(
                            i.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: isSel ? 24 : 18,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              color: isSel ? AppColors.primaryOrange : Colors.black87,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Phím tắt chọn nhanh phút phổ biến
            Wrap(
              spacing: 8,
              children: [0, 15, 30, 45].map((m) {
                final isSelected = _selectedMinute == m;
                return ChoiceChip(
                  label: Text(':${m.toString().padLeft(2, '0')}'),
                  selected: isSelected,
                  selectedColor: AppColors.primaryOrange.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppColors.primaryOrange : Colors.black87,
                  ),
                  onSelected: (_) => _setMinute(m),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Nút Xác nhận
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(
                    context,
                    TimeOfDay(hour: _selectedHour, minute: _selectedMinute),
                  );
                },
                child: Text(
                  'Xác Nhận Giờ ($hourStr:$minuteStr)',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
