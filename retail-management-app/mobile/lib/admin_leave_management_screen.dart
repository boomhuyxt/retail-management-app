import 'package:flutter/material.dart';

import 'core/leave_request_service.dart';
import 'theme.dart';

class AdminLeaveManagementScreen extends StatefulWidget {
  const AdminLeaveManagementScreen({super.key});

  @override
  State<AdminLeaveManagementScreen> createState() =>
      _AdminLeaveManagementScreenState();
}

class _AdminLeaveManagementScreenState
    extends State<AdminLeaveManagementScreen> {
  List<LeaveRequestItem> _pendingRequests = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      final requests = await LeaveRequestService.getAdminLeaveRequests(
        status: 'Pending',
        pageSize: 100,
      );
      if (!mounted) return;
      setState(() {
        _pendingRequests = requests;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = _readableError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _readableError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.contains('403') || message.toLowerCase().contains('quyền')) {
      return 'Tài khoản chưa có quyền xem hoặc duyệt đơn. Hãy kiểm tra role Admin/Chủ cửa hàng và cập nhật backend mới nhất.';
    }
    return message.isEmpty ? 'Không tải được danh sách đơn nghỉ phép.' : message;
  }

  Future<void> _showHistory() async {
    try {
      final allRequests = await LeaveRequestService.getAdminLeaveRequests(
        pageSize: 100,
      );
      if (!mounted) return;
      final history = allRequests
          .where((request) => request.status != 'Pending')
          .toList();
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => FractionallySizedBox(
          heightFactor: 0.82,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.bgLightCream,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                _sheetHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Lịch sử đơn nghỉ phép',
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Đóng',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: history.isEmpty
                      ? const Center(child: Text('Chưa có lịch sử xử lý đơn.'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: history.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) =>
                              _requestCard(history[index], showReview: false),
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) _showMessage(_readableError(error), isError: true);
    }
  }

  Widget _sheetHandle() => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );

  Widget _requestCard(LeaveRequestItem request, {bool showReview = true}) {
    final pending = request.status == 'Pending';
    final statusColor = switch (request.status) {
      'Pending' => AppColors.primaryOrange,
      'Approved' => Colors.green.shade700,
      'Rejected' || 'Cancelled' || 'Revoked' => Colors.red.shade700,
      _ => Colors.blueGrey,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E1DA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  request.employeeName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _statusChip(request.statusLabel, statusColor),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            request.employeeCode.isEmpty ? 'Mã nhân viên chưa có' : request.employeeCode,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _infoLine(Icons.event_outlined, request.requestedPeriod),
          const SizedBox(height: 7),
          _infoLine(Icons.category_outlined, _unitLabel(request.unit)),
          const SizedBox(height: 7),
          _infoLine(Icons.chat_bubble_outline, request.reasonLabel),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 27),
            child: Text(
              request.reason,
              style: const TextStyle(fontSize: 14, height: 1.35),
            ),
          ),
          if (request.isEmergency || request.isLateSubmission) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (request.isEmergency)
                  _statusChip('Khẩn cấp', Colors.deepOrange),
                if (request.isLateSubmission)
                  _statusChip('Nộp bổ sung', Colors.deepPurple),
              ],
            ),
          ],
          if (pending && showReview) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openReview(request),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Xem xét đơn'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _infoLine(IconData icon, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryOrange),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      );

  String _unitLabel(String unit) => switch (unit) {
        'Shift' => 'Nghỉ theo ca',
        'Day' => 'Nghỉ một ngày',
        'DateRange' => 'Nghỉ nhiều ngày',
        _ => unit,
      };

  Future<void> _openReview(LeaveRequestItem request) async {
    LeavePreviewModel preview;
    try {
      preview = await LeaveRequestService.reviewPreview(request.id);
    } catch (error) {
      if (mounted) _showMessage(_readableError(error), isError: true);
      return;
    }
    if (!mounted) return;

    final noteController = TextEditingController();
    var payrollTreatment = 'Unresolved';
    var longLeaveAcknowledged = false;
    var expandedCoverageAcknowledged = false;
    var submitting = false;
    String? actionError;

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: FractionallySizedBox(
            heightFactor: 0.92,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.bgLightCream,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  _sheetHandle(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Xét duyệt đơn nghỉ phép',
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Đóng',
                          onPressed: submitting
                              ? null
                              : () => Navigator.pop(sheetContext, false),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _requestCard(request, showReview: false),
                        const SizedBox(height: 14),
                        _sectionTitle('Thời gian nghỉ theo lịch'),
                        if (preview.effectiveIntervals.isEmpty)
                          const Text('Không có khoảng thời gian cụ thể.')
                        else
                          ...preview.effectiveIntervals.map((interval) {
                            final map = interval;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '${map['startLocal'] ?? ''} – ${map['endLocal'] ?? ''}',
                              ),
                            );
                          }),
                        const SizedBox(height: 8),
                        Text(
                          'Tổng thời gian nghỉ theo lịch: ${preview.scheduledLeaveMinutes} phút',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (preview.affectedAssignments.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _sectionTitle('Ca làm bị ảnh hưởng'),
                          ...preview.affectedAssignments.map((assignment) {
                            final map = assignment;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: const Icon(Icons.schedule),
                              title: Text(map['shiftName']?.toString() ?? 'Ca làm'),
                              subtitle: Text(
                                '${map['shiftDate'] ?? ''} · ${map['startTime'] ?? ''}–${map['endTime'] ?? ''} · ${map['scheduledMinutes'] ?? 0} phút',
                              ),
                            );
                          }),
                        ],
                        if (preview.warnings.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...preview.warnings.map(
                            (warning) => Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Text(
                                '⚠ $warning',
                                style: TextStyle(color: Colors.orange.shade900),
                              ),
                            ),
                          ),
                        ],
                        if (preview.hasConflict) ...[
                          const SizedBox(height: 10),
                          Text(
                            preview.conflictReason ?? 'Đơn có xung đột, không thể duyệt.',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                        if (preview.isLongLeave) ...[
                          const SizedBox(height: 10),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: longLeaveAcknowledged,
                            onChanged: (value) => setSheetState(
                              () => longLeaveAcknowledged = value ?? false,
                            ),
                            title: const Text('Xác nhận đã xem xét đơn nghỉ dài hạn'),
                          ),
                        ],
                        if (preview.hasExpandedCoverage)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: expandedCoverageAcknowledged,
                            onChanged: (value) => setSheetState(
                              () => expandedCoverageAcknowledged = value ?? false,
                            ),
                            title: const Text('Xác nhận phạm vi nghỉ đã mở rộng theo lịch làm'),
                          ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: payrollTreatment,
                          decoration: const InputDecoration(
                            labelText: 'Phương án lương',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Unresolved', child: Text('Chưa phân loại')),
                            DropdownMenuItem(value: 'PaidLeave', child: Text('Hưởng lương')),
                            DropdownMenuItem(value: 'UnpaidLeave', child: Text('Không hưởng lương')),
                            DropdownMenuItem(value: 'ExternalBenefitReview', child: Text('Chế độ riêng cần xem xét')),
                          ],
                          onChanged: submitting
                              ? null
                              : (value) => setSheetState(
                                    () => payrollTreatment = value ?? 'Unresolved',
                                  ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: noteController,
                          maxLength: 2000,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Ghi chú xét duyệt',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        if (preview.isLongLeave)
                          const Text(
                            'Đơn trên 30 ngày cần ghi chú xét duyệt.',
                            style: TextStyle(color: Colors.deepOrange),
                          ),
                        if (actionError != null) ...[
                          const SizedBox(height: 8),
                          Text(actionError!, style: const TextStyle(color: Colors.red)),
                        ],
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: submitting
                                  ? null
                                  : () async {
                                      final reason = await _askRejectReason(sheetContext);
                                      if (reason == null || reason.trim().isEmpty) return;
                                      setSheetState(() {
                                        submitting = true;
                                        actionError = null;
                                      });
                                      try {
                                        await LeaveRequestService.reject(
                                          id: request.id,
                                          version: preview.existingVersion ?? request.version,
                                          reason: reason.trim(),
                                        );
                                        if (sheetContext.mounted) {
                                          Navigator.pop(sheetContext, true);
                                        }
                                      } catch (error) {
                                        setSheetState(() {
                                          submitting = false;
                                          actionError = _readableError(error);
                                        });
                                      }
                                    },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                minimumSize: const Size.fromHeight(48),
                              ),
                              child: const Text('Từ chối'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: submitting || preview.hasConflict
                                  ? null
                                  : () async {
                                      if (preview.isLongLeave &&
                                          !longLeaveAcknowledged) {
                                        setSheetState(() => actionError =
                                            'Hãy xác nhận đã xem xét đơn nghỉ dài hạn.');
                                        return;
                                      }
                                      if (preview.isLongLeave &&
                                          noteController.text.trim().isEmpty) {
                                        setSheetState(() => actionError =
                                            'Vui lòng nhập ghi chú cho đơn nghỉ dài hạn.');
                                        return;
                                      }
                                      if (preview.hasExpandedCoverage &&
                                          !expandedCoverageAcknowledged) {
                                        setSheetState(() => actionError =
                                            'Hãy xác nhận phạm vi nghỉ theo lịch làm.');
                                        return;
                                      }
                                      setSheetState(() {
                                        submitting = true;
                                        actionError = null;
                                      });
                                      try {
                                        await LeaveRequestService.approve(
                                          id: request.id,
                                          version: preview.existingVersion ?? request.version,
                                          previewToken: preview.previewToken,
                                          payrollTreatment: payrollTreatment,
                                          reviewNote: noteController.text.trim(),
                                          longLeaveAcknowledged: longLeaveAcknowledged,
                                          expandedCoverageAcknowledged: expandedCoverageAcknowledged,
                                        );
                                        if (sheetContext.mounted) {
                                          Navigator.pop(sheetContext, true);
                                        }
                                      } catch (error) {
                                        setSheetState(() {
                                          submitting = false;
                                          actionError = _readableError(error);
                                        });
                                      }
                                    },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryOrange,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                              ),
                              child: submitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Duyệt đơn'),
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
        ),
      ),
    );

    noteController.dispose();
    if (changed == true && mounted) {
      await _loadPendingRequests();
      _showMessage('Đã cập nhật quyết định nghỉ phép.');
    }
  }

  Future<String?> _askRejectReason(BuildContext context) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Từ chối đơn nghỉ phép'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: 'Lý do từ chối',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('Xác nhận từ chối'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
      );

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLightCream,
      appBar: AppBar(
        title: const Text(
          'Quản Lý Nghỉ Phép',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại danh sách',
            onPressed: _loading ? null : () => _loadPendingRequests(),
            icon: const Icon(Icons.refresh, color: AppColors.primaryOrange),
          ),
          IconButton(
            tooltip: 'Lịch sử duyệt đơn',
            onPressed: _showHistory,
            icon: const Icon(Icons.history, color: AppColors.primaryOrange),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primaryOrange,
        onRefresh: () => _loadPendingRequests(showLoading: false),
        child: _loading && _pendingRequests.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator()),
                  SizedBox(height: 16),
                  Center(child: Text('Đang tải đơn cần duyệt…')),
                ],
              )
            : _loadError != null && _pendingRequests.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 150),
                      Icon(Icons.cloud_off_outlined,
                          size: 54, color: Colors.grey.shade500),
                      const SizedBox(height: 16),
                      Text(_loadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: () => _loadPendingRequests(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Thử tải lại'),
                        ),
                      ),
                    ],
                  )
                : _pendingRequests.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: MediaQuery.sizeOf(context).height * .22),
                          Icon(Icons.assignment_turned_in_outlined,
                              size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Center(
                            child: Text(
                              'Không có đơn nghỉ phép nào cần duyệt',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 15),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: OutlinedButton.icon(
                              onPressed: _showHistory,
                              icon: const Icon(Icons.history),
                              label: const Text('Xem lịch sử duyệt đơn'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryOrange,
                                side: const BorderSide(color: AppColors.primaryOrange),
                                minimumSize: const Size(220, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _pendingRequests.length + 1,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                '${_pendingRequests.length} đơn đang chờ duyệt',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }
                          return _requestCard(_pendingRequests[index - 1]);
                        },
                      ),
      ),
    );
  }
}
