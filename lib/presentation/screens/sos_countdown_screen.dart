import 'dart:async';

import 'package:flutter/material.dart';

/// Màn hình đếm ngược trước khi kích hoạt SOS.
///
/// Hiển thị "3... 2... 1..." kèm hiệu ứng cảnh báo trực quan (vòng tròn
/// đồng hồ co lại, màu đỏ nhấp nháy) để người dùng nhận ra mình đang ấn nhầm
/// và có thể bấm **HỦY** kịp thời.
class SosCountdownScreen extends StatefulWidget {
  const SosCountdownScreen({
    super.key,
    required this.onConfirm,
    required this.onCancel,
    this.totalSeconds = 3,
  });

  /// Được gọi khi đếm ngược về 0 và người dùng không hủy.
  final VoidCallback onConfirm;

  /// Được gọi khi người dùng bấm nút HỦY.
  final VoidCallback onCancel;

  /// Tổng số giây đếm ngược.
  final int totalSeconds;

  @override
  State<SosCountdownScreen> createState() => _SosCountdownScreenState();
}

class _SosCountdownScreenState extends State<SosCountdownScreen>
    with SingleTickerProviderStateMixin {
  late int _remaining;
  Timer? _timer;
  late final AnimationController _pulse;

  /// Đã kết thúc (xác nhận hoặc huỷ) — ngăn callback hẹn giờ kích hoạt nhầm.
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.totalSeconds;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _finished) return;
      setState(() {
        _remaining--;
      });
      if (_remaining <= 0) {
        timer.cancel();
        _finished = true;
        widget.onConfirm();
      }
    });
  }

  /// Dừng đếm ngược ngay lập tức rồi báo cho lời gọi bên ngoài.
  ///
  /// Phải huỷ timer *trước khi* đóng dialog, nếu không callback tới hạn sẽ
  /// kích hoạt SOS dù người dùng đã bấm HỦY.
  void _finish(VoidCallback action) {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    _timer = null;
    action();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int display = _remaining < 0 ? 0 : _remaining;
    final double progress = display / widget.totalSeconds;

    return Dialog(
      backgroundColor: const Color(0xFF18191F),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 44),
            const SizedBox(height: 12),
            const Text(
              'CHẾ ĐỘ KHẨN CẤP SẮP KÍCH HOẠT',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Toạ độ của bạn sẽ được gửi tới các thành viên gia đình.\nNhấn HỦY nếu bạn ấn nhầm.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 22),
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final double scale = 0.92 + 0.08 * _pulse.value;
                return Transform.scale(scale: scale, child: child);
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: CircularProgressIndicator(
                      value: progress <= 0 ? 1 : progress,
                      strokeWidth: 8,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                    ),
                  ),
                  Text(
                    '$display',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 76,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _finish(widget.onCancel),
                icon: const Icon(Icons.close_rounded),
                label: const Text(
                  'HỦY',
                  style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38, width: 1.6),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
