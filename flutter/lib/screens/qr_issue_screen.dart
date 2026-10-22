import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/qr_login_ticket.dart';
import '../services/qr_auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/api_error_messages.dart';
import '../utils/qr_countdown.dart';
import '../utils/short_code.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';

/// 보호자가 아이 기기 로그인을 연결하는 화면: QR 이미지 + 6자리 숫자 코드 + 만료 카운트다운.
/// RN `frontend/app/qr-issue/[kidMemberId].tsx`에 대응.
///
/// QR 토큰 문자열은 QR 이미지로만 인코딩하고 텍스트/semantics/로그 어디에도 노출하지 않는다.
class QrIssueScreen extends StatefulWidget {
  const QrIssueScreen({
    super.key,
    required this.kidMemberId,
    required this.kidName,
    this.now = DateTime.now,
  });

  final String kidMemberId;
  final String kidName;

  /// 테스트에서 시계를 주입하기 위한 훅.
  final DateTime Function() now;

  @override
  State<QrIssueScreen> createState() => _QrIssueScreenState();
}

class _QrIssueScreenState extends State<QrIssueScreen> {
  QrLoginTicket? _ticket;
  int _secondsLeft = 0;
  bool _loading = true;
  bool _expired = false;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _issue();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _issue() async {
    _timer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
      _expired = false;
      _ticket = null;
    });
    try {
      final ticket =
          await context.read<QrAuthService>().issue(widget.kidMemberId);
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _secondsLeft = remainingSeconds(ticket.expiresAt, widget.now());
        _expired = _secondsLeft <= 0;
      });
      if (!_expired) {
        _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      }
    } catch (e) {
      if (mounted) setState(() => _error = issueQrErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _tick() {
    final ticket = _ticket;
    if (ticket == null) return;
    final left = remainingSeconds(ticket.expiresAt, widget.now());
    setState(() {
      _secondsLeft = left;
      if (left <= 0) {
        // 만료된 토큰/코드는 메모리에서도 버린다.
        _expired = true;
        _ticket = null;
      }
    });
    if (left <= 0) _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR로 로그인 연결하기', style: AppTextStyles.cardTitle),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                HintBanner(
                  '이 화면을 ${widget.kidName} 기기 카메라에 보여주세요.\n'
                  '2분 안에 스캔해야 해요.',
                ),
                const SizedBox(height: 16),
                SectionCard(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    height: 260,
                    child: Center(child: _buildQrArea()),
                  ),
                ),
                ..._buildBelowQr(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQrArea() {
    if (_loading) {
      return const CircularProgressIndicator(color: AppColors.accent);
    }
    if (_error != null) {
      return Text(
        _error!,
        style: const TextStyle(color: AppColors.danger, fontSize: 14),
      );
    }
    if (_expired) {
      return const Text(
        '⏰ 시간이 지났어요',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      );
    }
    final ticket = _ticket;
    if (ticket == null) return const SizedBox.shrink();
    return QrImageView(
      data: ticket.token,
      size: 240,
      backgroundColor: AppColors.card,
      semanticsLabel: '아이 기기 로그인용 QR 코드',
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: AppColors.textPrimary,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: AppColors.textPrimary,
      ),
    );
  }

  List<Widget> _buildBelowQr() {
    if (_loading) return const [];
    final ticket = _ticket;
    return [
      if (ticket != null && !_expired) ...[
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '또는 이 번호를 아이에게 알려주세요',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.bannerText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formatShortCode(ticket.shortCode),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '남은 시간 ${formatCountdown(_secondsLeft)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
      if (_expired) ...[
        const SizedBox(height: 16),
        const Text(
          '다시 만들어주세요',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.danger,
          ),
        ),
      ],
      if (_expired || _error != null) ...[
        const SizedBox(height: 20),
        PrimaryButton(label: '새로 만들기', onPressed: _issue),
      ],
    ];
  }
}
