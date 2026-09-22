import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'theme.dart';

class DashboardQRScreen extends StatefulWidget {
  const DashboardQRScreen({Key? key}) : super(key: key);

  @override
  State<DashboardQRScreen> createState() => _DashboardQRScreenState();
}

class _DashboardQRScreenState extends State<DashboardQRScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false; // Tránh việc camera quét liên tục 1 mã nhiều lần

  // Danh sách lịch sử vào ca / ra ca mẫu
  final List<Map<String, String>> _attendanceHistory = [
    {
      'type': 'Vào ca',
      'time': '08:00 - 22/09/2026',
      'status': 'Đúng giờ',
    },
    {
      'type': 'Ra ca',
      'time': '17:05 - 21/09/2026',
      'status': 'Đúng giờ',
    },
  ];

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  // Xử lý khi camera phát hiện mã QR
  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      setState(() {
        _isProcessing = true;
      });

      final String codeValue = barcodes.first.rawValue!;

      // Tự động xác định Vào ca / Ra ca dựa trên lượt gần nhất
      final String nextType = (_attendanceHistory.isEmpty || _attendanceHistory.first['type'] == 'Ra ca')
          ? 'Vào ca'
          : 'Ra ca';

      final String currentTime = _getCurrentFormattedTime();

      // Thêm lượt quét mới vào lịch sử
      setState(() {
        _attendanceHistory.insert(0, {
          'type': nextType,
          'time': currentTime,
          'status': 'Thành công',
        });
      });

      // Hiển thị thông báo thành công
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quét thành công ($nextType): $codeValue'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Đợi 3 giây trước khi cho phép quét lượt tiếp theo
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      });
    }
  }

  String _getCurrentFormattedTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year;
    return '$hour:$minute - $day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLightCream,
      appBar: AppBar(
        title: const Text('Điểm Danh QR', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.grey),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // MÀN HÌNH SCAN QR
              Container(
                height: 280,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryOrange, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: _onDetect,
                      ),
                      // Khung ngắm quét mã QR
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _isProcessing ? Colors.green : AppColors.primaryOrange,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      if (_isProcessing)
                        Container(
                          color: Colors.black45,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: AppColors.primaryOrange),
                                SizedBox(height: 8),
                                Text(
                                  'Đã ghi nhận điểm danh!',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              const Text(
                'Di chuyển camera đến mã QR cửa hàng để điểm danh',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // DANH SÁCH LỊCH SỬ VÀO CA / RA CA
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Lịch sử điểm danh',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        Icon(Icons.history, size: 20, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _attendanceHistory.isEmpty
                          ? const Center(child: Text('Chưa có dữ liệu điểm danh', style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                        itemCount: _attendanceHistory.length,
                        itemBuilder: (context, index) {
                          final item = _attendanceHistory[index];
                          final isCheckIn = item['type'] == 'Vào ca';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 6,
                                )
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isCheckIn
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.orange.withValues(alpha: 0.1),
                                  child: Icon(
                                    isCheckIn ? Icons.login : Icons.logout,
                                    color: isCheckIn ? Colors.green : Colors.orange,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['type']!,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item['time']!,
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item['status']!,
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}