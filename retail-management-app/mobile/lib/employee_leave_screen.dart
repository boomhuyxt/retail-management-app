import 'package:flutter/material.dart';
import 'core/auth_service.dart';
import 'theme.dart';

class EmployeeLeaveScreen extends StatefulWidget {
  const EmployeeLeaveScreen({super.key});

  @override
  State<EmployeeLeaveScreen> createState() => _EmployeeLeaveScreenState();
}

class _EmployeeLeaveScreenState extends State<EmployeeLeaveScreen> {
  // Lịch sử gửi đơn xin nghỉ của nhân viên (mặc định trống)
  final List<Map<String, dynamic>> _leaveRequests = [];

  /// Hàm mở Dialog/BottomSheet Tạo Đơn Xin Nghỉ Phép Online
  void _showAddLeaveModal() {
    final user = AuthService.currentUser;

    // Controllers & Form State
    final reasonController = TextEditingController();
    final handoverController = TextEditingController();

    String leaveType = 'Nghỉ phép năm';
    String shiftType = 'Cả ngày';
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {

            // Hàm chọn ngày
            Future<void> pickDate(bool isStart) async {
              final picked = await showDatePicker(
                context: context,
                initialDate: isStart ? startDate : endDate,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setModalState(() {
                  if (isStart) {
                    startDate = picked;
                    if (endDate.isBefore(startDate)) endDate = startDate;
                  } else {
                    endDate = picked;
                  }
                });
              }
            }

            String formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: const BoxDecoration(
                color: AppColors.bgLightCream,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // --- HEADER DẠNG THANH TIÊU ĐỀ ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tạo Đơn Xin Nghỉ Phép',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // --- FORM NHẬP THÔNG TIN CHI TIẾT ---
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. THÔNG TIN NGƯỜI GỬI (TỰ ĐỘNG)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.account_circle, color: AppColors.primaryOrange, size: 36),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user?.displayName ?? 'Chưa xác định',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Mã NV: ${user?.id ?? "N/A"} | Chức vụ: ${user?.role ?? "Nhân viên"}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 2. LOẠI NGHỈ PHÉP & CA NGHỈ
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: leaveType,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Loại nghỉ phép',
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  items: ['Nghỉ phép năm', 'Nghỉ ốm', 'Nghỉ việc riêng', 'Nghỉ không lương']
                                      .map((type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(type, style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      ),
                                  ))
                                      .toList(),
                                  onChanged: (val) => setModalState(() => leaveType = val!),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: shiftType,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Phạm vi ca nghỉ',
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  items: ['Cả ngày', 'Ca sáng', 'Ca chiều']
                                      .map((shift) => DropdownMenuItem(value: shift, child: Text(shift, style: const TextStyle(fontSize: 13))))
                                      .toList(),
                                  onChanged: (val) => setModalState(() => shiftType = val!),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 3. THỜI GIAN NGHỈ (TỪ NGÀY -> ĐẾN NGÀY)
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => pickDate(true),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'Từ ngày',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      suffixIcon: const Icon(Icons.calendar_today, size: 18),
                                    ),
                                    child: Text(formatDate(startDate), style: const TextStyle(fontSize: 14)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () => pickDate(false),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'Đến ngày',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      suffixIcon: const Icon(Icons.calendar_today, size: 18),
                                    ),
                                    child: Text(formatDate(endDate), style: const TextStyle(fontSize: 14)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 4. NHÂN VIÊN LÀM THAY / BÀN GIAO (KHÔNG BẮT BUỘC)
                          TextField(
                            controller: handoverController,
                            decoration: InputDecoration(
                              labelText: 'Người bàn giao / Hỗ trợ ca (Nếu có)',
                              hintText: 'Nhập tên hoặc Mã NV gánh ca...',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.swap_horiz, size: 20),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 5. LÝ DO XIN NGHỈ (BẮT BUỘC)
                          TextField(
                            controller: reasonController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Lý do xin nghỉ (*)',
                              hintText: 'Trình bày lý do xin nghỉ chi tiết...',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 6. NÚT NỘP ĐƠN ONLINE
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryOrange,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 2,
                              ),
                              onPressed: () {
                                if (reasonController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Vui lòng điền lý do xin nghỉ!')),
                                  );
                                  return;
                                }

                                final dateText = startDate == endDate
                                    ? '${formatDate(startDate)} ($shiftType)'
                                    : '${formatDate(startDate)} - ${formatDate(endDate)} ($shiftType)';

                                setState(() {
                                  _leaveRequests.insert(0, {
                                    'title': '$leaveType - $shiftType',
                                    'reason': reasonController.text.trim(),
                                    'date': dateText,
                                    'handover': handoverController.text.trim(),
                                    'status': 'Đang chờ duyệt',
                                    'statusColor': Colors.orange,
                                    'createdAt': 'Hôm nay',
                                  });
                                });

                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Đã gửi đơn xin nghỉ phép thành công!')),
                                );
                              },
                              child: const Text(
                                'Gửi Đơn Xin Nghỉ',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLightCream,
      appBar: AppBar(
        title: const Text(
          'Lịch Sử Đơn Nghỉ Phép',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _leaveRequests.isEmpty
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Chưa gửi đơn nghỉ phép nào',
              style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            const Text(
              'Nhấn nút bên dưới để tạo đơn xin nghỉ phép mới',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _leaveRequests.length,
        itemBuilder: (context, index) {
          final item = _leaveRequests[index];
          final String handover = item['handover'] ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hàng Tiêu đề loại nghỉ & Nhãn Trạng thái
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item['title'] ?? 'Nghỉ phép',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (item['statusColor'] as Color).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item['status'],
                        style: TextStyle(color: item['statusColor'], fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Ngày xin nghỉ & Lý do
                Text('Thời gian: ${item['date']}', style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('Lý do: ${item['reason']}', style: const TextStyle(fontSize: 13)),

                // Người làm thay (nếu có)
                if (handover.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Bàn giao/Gánh ca: $handover', style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLeaveModal,
        backgroundColor: AppColors.primaryOrange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tạo đơn mới', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}