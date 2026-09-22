import 'package:flutter/material.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({Key? key}) : super(key: key);

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  // Mock Data danh sách nhân viên và ca làm trong tuần
  final List<Map<String, dynamic>> _staffSchedules = [
    {
      'name': 'Trần Minh Khang',
      'code': 'QM-10101',
      'role': 'lead',
      'shifts': ['Sáng', 'Sáng', 'Sáng', 'Chiều', 'Chiều', 'Sáng', 'OFF'],
    },
    {
      'name': 'Nguyễn Thảo My',
      'code': 'QM-88219',
      'role': 'cashier',
      'shifts': ['Chiều', 'Chiều', 'OFF', 'Sáng', 'Sáng', 'Chiều', 'Chiều'],
    },
    {
      'name': 'Lê Hoàng Long',
      'code': 'QM-77342',
      'role': 'cashier',
      'shifts': ['Đêm', 'Đêm', 'Đêm', 'Đêm', 'OFF', 'Đêm', 'Đêm'],
    },
  ];

  Color _getShiftColor(String shift) {
    switch (shift) {
      case 'Sáng':
        return Colors.orange.shade100;
      case 'Chiều':
        return Colors.blue.shade100;
      case 'Đêm':
        return Colors.purple.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  void _showEditShiftDialog(String staffName, int dayIndex, String currentShift) {
    showDialog(
      context: context,
      builder: (context) {
        String selectedShift = currentShift;
        return AlertDialog(
          title: Text('Đổi Ca - $staffName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['Sáng', 'Chiều', 'Đêm', 'OFF'].map((shift) {
              return RadioListTile<String>(
                title: Text(shift),
                value: shift,
                groupValue: selectedShift,
                onChanged: (val) {
                  setState(() {
                    selectedShift = val!;
                  });
                  Navigator.pop(context);
                  _updateShift(staffName, dayIndex, selectedShift);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _updateShift(String staffName, int dayIndex, String newShift) {
    setState(() {
      final staff = _staffSchedules.firstWhere((element) => element['name'] == staffName);
      staff['shifts'][dayIndex] = newShift;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã cập nhật ca $newShift cho $staffName')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng Phân Công Ca Làm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tuần 38 (15/09 - 21/09)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),

            // Responsive Data Table
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                columns: const [
                  DataColumn(label: Text('Nhân Viên', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('T2')),
                  DataColumn(label: Text('T3')),
                  DataColumn(label: Text('T4')),
                  DataColumn(label: Text('T5')),
                  DataColumn(label: Text('T6')),
                  DataColumn(label: Text('T7 (Hôm Nay)')),
                  DataColumn(label: Text('CN')),
                ],
                rows: _staffSchedules.map((staff) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(staff['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text(staff['code'], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                      ...List.generate(7, (index) {
                        final shift = staff['shifts'][index];
                        return DataCell(
                          InkWell(
                            onTap: () => _showEditShiftDialog(staff['name'], index, shift),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getShiftColor(shift),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(shift, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}