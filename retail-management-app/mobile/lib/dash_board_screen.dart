import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'core/attendance_service.dart';
import 'core/auth_service.dart';
import 'theme.dart';

class DashboardQRScreen extends StatefulWidget {
  const DashboardQRScreen({super.key});

  @override
  State<DashboardQRScreen> createState() => _DashboardQRScreenState();
}

class _DashboardQRScreenState extends State<DashboardQRScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;
  bool _isLoadingHistory = false;

  final List<ShiftRecordModel> _shiftHistory = [];

  // Biến phục vụ phân quyền Role & Mã QR Admin
  bool _isAdminOrOwner = false;
  String _adminQrData = '';
  int _qrSecondsLeft = 30;
  Timer? _qrTimer;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _loadHistory();
  }

  void _checkUserRole() {
    final user = AuthService.currentUser;
    final role = user?.role.toLowerCase() ?? '';
    final isAdmin = role == 'admin' || role == 'owner' || role == 'chủ cửa hàng';

    setState(() {
      _isAdminOrOwner = isAdmin;
    });

    if (isAdmin) {
      _generateNewAdminQrCode();
      _startAdminQrTimer();
    }
  }

  /// Sinh chuỗi mã QR động dành cho Admin/Chủ cửa hàng
  void _generateNewAdminQrCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _adminQrData = 'RETAIL365_KIOSK_STORE_01_$timestamp';
      _qrSecondsLeft = 30;
    });
  }

  /// Bộ đếm ngược 30s tự động đổi mã QR chống chụp ảnh gian lận
  void _startAdminQrTimer() {
    _qrTimer?.cancel();
    _qrTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_qrSecondsLeft > 1) {
        setState(() {
          _qrSecondsLeft--;
        });
      } else {
        _generateNewAdminQrCode();
      }
    });
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    final records = await AttendanceService.getShiftHistory();
    if (!mounted) return;

    setState(() {
      _isLoadingHistory = false;
      _shiftHistory.clear();
      _shiftHistory.addAll(records);
    });
  }

  @override
  void dispose() {
    _qrTimer?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _processQrCode(String codeValue) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    final result = await AttendanceService.verifyQr(codeValue);

    if (!mounted) return;

    if (!result.isSuccess) {
      _showErrorDialog('Lỗi quét mã QR', result.message);
      _unlockScannerAfterDelay();
      return;
    }

    // Hiển thị BottomSheet chọn ca và xác nhận thao tác
    await _showShiftSelectionBottomSheet(result, codeValue);
    _unlockScannerAfterDelay();
  }

  void _unlockScannerAfterDelay() {
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String codeValue = barcodes.first.rawValue!;
      _processQrCode(codeValue);
    }
  }

  Future<void> _showShiftSelectionBottomSheet(
      VerifyQrResult verifyResult,
      String qrPayload,
      ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tiêu đề Kiosk
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.storefront,
                      color: AppColors.primaryOrange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          verifyResult.storeName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          'Mã trạm: ${verifyResult.storeCode} • QR Hợp lệ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              const Text(
                'DANH SÁCH CA LÀM VIỆC CỦA BẠN:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 10),

              if (verifyResult.eligibleShifts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Hôm nay bạn không có ca làm việc nào được phân công tại chi nhánh này.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ...verifyResult.eligibleShifts.map(
                      (shift) => _buildShiftCard(shift, qrPayload, ctx),
                ),

              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShiftCard(
      EligibleShiftModel shift,
      String qrPayload,
      BuildContext bottomSheetContext,
      ) {
    Color statusColor = Colors.grey;
    String statusText = 'Chưa vào ca';
    if (shift.status == 'CheckedIn') {
      statusColor = Colors.blue;
      statusText = 'Đang trong ca';
    } else if (shift.status == 'Completed') {
      statusColor = Colors.green;
      statusText = 'Đã hoàn tất ca';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgLightCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: shift.status == 'CheckedIn'
              ? Colors.blue.shade200
              : const Color(0xFFEADCCF),
          width: shift.status == 'CheckedIn' ? 1.5 : 1.0,
        ),
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
                  fontSize: 15,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Khung giờ: ${shift.startTime} - ${shift.endTime}${shift.isOvernight ? " (Qua đêm)" : ""}',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
          if (shift.checkInAt != null) ...[
            const SizedBox(height: 4),
            Text(
              '• Giờ Check-in: ${DateFormat("HH:mm:ss").format(shift.checkInAt!)}',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
            ),
          ],
          if (shift.checkOutAt != null) ...[
            Text(
              '• Giờ Check-out: ${DateFormat("HH:mm:ss").format(shift.checkOutAt!)} (${shift.actualHours ?? 0}h)',
              style: TextStyle(fontSize: 12, color: Colors.green.shade700),
            ),
          ],
          const SizedBox(height: 10),

          // NÚT THAO TÁC THEO CA
          if (shift.allowedAction == 'CHECK_IN')
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.login, color: Colors.white, size: 18),
                label: const Text(
                  'Xác nhận Vào Ca (Check-in)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () => _handleSubmit(
                  shift.shiftAssignmentId,
                  'CHECK_IN',
                  qrPayload,
                  bottomSheetContext,
                ),
              ),
            )
          else if (shift.allowedAction == 'CHECK_OUT')
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.logout, color: Colors.white, size: 18),
                label: const Text(
                  'Xác nhận Tan Ca (Check-out)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () => _handleSubmit(
                  shift.shiftAssignmentId,
                  'CHECK_OUT',
                  qrPayload,
                  bottomSheetContext,
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  '✓ Đã chấm công xong ca này',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleSubmit(
      int? shiftAssignmentId,
      String action,
      String qrPayload,
      BuildContext bottomSheetContext,
      ) async {
    Navigator.pop(bottomSheetContext); // Đóng BottomSheet

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryOrange),
      ),
    );

    final result = await AttendanceService.submitAttendance(
      shiftAssignmentId: shiftAssignmentId,
      action: action,
      qrPayload: qrPayload,
    );

    if (!mounted) return;
    Navigator.pop(context); // Đóng Loading Dialog

    if (result.isSuccess) {
      final locationMessage = result.location == null
          ? ''
          : '\nVị trí hợp lệ: cách cửa hàng ${result.location!.distanceMeters.toStringAsFixed(1)}m '
          '(bán kính ${result.location!.allowedRadiusMeters.toStringAsFixed(0)}m, '
          'sai số GPS ${result.location!.accuracyMeters.toStringAsFixed(1)}m).';
      _showSuccessDialog(
        title: action == 'CHECK_IN'
            ? 'Check-in thành công!'
            : 'Check-out thành công!',
        message: '${result.message}$locationMessage',
      );
      _loadHistory(); // Nạp lại lịch sử
    } else {
      _showErrorDialog('Chấm công không thành công', result.message);
    }
  }

  void _showSuccessDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Đóng',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Đóng',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showManualInputDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Nhập mã QR thủ công (Test)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'Dán chuỗi token QR tại đây...',
            border: OutlineInputBorder(),
          ),
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
              final val = textController.text.trim();
              Navigator.pop(ctx);
              if (val.isNotEmpty) {
                _processQrCode(val);
              }
            },
            child: const Text(
              'Xác thực QR',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLightCream,
      appBar: AppBar(
        title: Text(
          _isAdminOrOwner ? 'Mã QR Trạm Chấm Công' : 'Điểm Danh QR Theo Ca',
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: _isAdminOrOwner
            ? []
            : [
          IconButton(
            icon: const Icon(Icons.keyboard, color: AppColors.primaryOrange),
            tooltip: 'Nhập mã QR thủ công',
            onPressed: _showManualInputDialog,
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.grey),
            tooltip: 'Đổi camera',
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // 1. NẾU LÀ ADMIN / CHỦ CỬA HÀNG -> HIỂN THỊ MÃ QR DÀNH CHO NHÂN VIÊN QUÉT
              if (_isAdminOrOwner) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'MÃ QR ĐIỂM DANH CỬA HÀNG',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Cho nhân viên quét mã này bằng ứng dụng để check-in / check-out',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primaryOrange.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: QrImageView(
                          data: _adminQrData,
                          version: QrVersions.auto,
                          size: 200.0,
                          foregroundColor: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryOrange,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Làm mới mã sau $_qrSecondsLeft giây',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryOrange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primaryOrange),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          _generateNewAdminQrCode();
                          _startAdminQrTimer();
                        },
                        icon: const Icon(
                          Icons.refresh,
                          size: 18,
                          color: AppColors.primaryOrange,
                        ),
                        label: const Text(
                          'Tạo mã mới ngay',
                          style: TextStyle(
                            color: AppColors.primaryOrange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]
              // 2. NẾU LÀ NHÂN VIÊN -> HIỂN THỊ CAMERA QUÉT QR MẶC ĐỊNH
              else ...[
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
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _isProcessing
                                  ? Colors.green
                                  : AppColors.primaryOrange,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        if (_isProcessing)
                          Container(
                            color: Colors.black54,
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    color: AppColors.primaryOrange,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Đang xác thực mã QR...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
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
                  'Hướng camera về phía mã QR động tại Kiosk cửa hàng để chọn ca chấm công',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 20),

              // LỊCH SỬ CHẤM CÔNG THEO CA
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Lịch sử ca làm việc',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.refresh,
                            size: 20,
                            color: Colors.grey,
                          ),
                          onPressed: _loadHistory,
                          tooltip: 'Làm mới lịch sử',
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: _isLoadingHistory
                          ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryOrange,
                        ),
                      )
                          : _shiftHistory.isEmpty
                          ? const Center(
                        child: Text(
                          'Chưa có lịch sử chấm công ca nào',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                          : ListView.builder(
                        itemCount: _shiftHistory.length,
                        itemBuilder: (context, index) {
                          final item = _shiftHistory[index];
                          final hasCheckOut = item.checkOutAt != null;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: 0.03,
                                  ),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                  (hasCheckOut
                                      ? Colors.green
                                      : Colors.blue)
                                      .withValues(alpha: 0.1),
                                  child: Icon(
                                    hasCheckOut
                                        ? Icons.check_circle
                                        : Icons.timer,
                                    color: hasCheckOut
                                        ? Colors.green
                                        : Colors.blue,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${item.shiftName} (${item.shiftDate})',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Vào: ${DateFormat("HH:mm - dd/MM").format(item.checkInAt)}${item.checkOutAt != null ? " • Ra: ${DateFormat("HH:mm - dd/MM").format(item.checkOutAt!)}" : " • Đang làm việc..."}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                    (hasCheckOut
                                        ? Colors.green
                                        : Colors.blue)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                      6,
                                    ),
                                  ),
                                  child: Text(
                                    hasCheckOut
                                        ? '${item.actualHours ?? 0}h'
                                        : 'Trong ca',
                                    style: TextStyle(
                                      color: hasCheckOut
                                          ? Colors.green
                                          : Colors.blue,
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