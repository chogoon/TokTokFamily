import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../services/camera_permission_gateway.dart';
import '../services/qr_auth_service.dart';
import '../state/auth_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/api_error_messages.dart';
import '../utils/camera_permission.dart';
import '../widgets/kid_login_message.dart';
import 'kid_enter_code_screen.dart';

export '../services/camera_permission_gateway.dart' show CameraPermissionGateway;

/// QR 값을 받으면 [onCode]를 부르는 스캐너 위젯을 만든다. 테스트에서는 실제 카메라 대신 fake를 넣는다.
typedef QrScannerBuilder = Widget Function(
    BuildContext context, ValueChanged<String> onCode);

/// 아이 기기: 부모님 화면의 QR을 스캔해 로그인. RN `app/(auth)/scan-qr.tsx`에 대응.
///
/// 스캔한 토큰 문자열은 backend로만 보내고 화면 텍스트/semantics/로그에 남기지 않는다.
class KidScanQrScreen extends StatefulWidget {
  const KidScanQrScreen({
    super.key,
    this.permission = const PermissionHandlerCameraGateway(),
    this.scannerBuilder = _defaultScanner,
    this.codeScreenBuilder,
  });

  final CameraPermissionGateway permission;
  final QrScannerBuilder scannerBuilder;

  /// "번호로 입력하기" 대상 화면 (테스트 주입용). 기본은 [KidEnterCodeScreen].
  final WidgetBuilder? codeScreenBuilder;

  @override
  State<KidScanQrScreen> createState() => _KidScanQrScreenState();
}

enum _Phase { scanning, loading, error }

class _KidScanQrScreenState extends State<KidScanQrScreen>
    with WidgetsBindingObserver {
  CameraPermissionState? _permission;
  _Phase _phase = _Phase.scanning;
  String? _error;

  /// 카메라는 같은 QR을 초당 여러 번 감지한다 — 첫 감지만 처리한다.
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // OS 설정에서 카메라를 켜고 돌아오면 다시 확인한다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _permission != CameraPermissionState.granted) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final state = await widget.permission.check();
    if (mounted) setState(() => _permission = state);
  }

  Future<void> _requestPermission() async {
    final state = await widget.permission.request();
    if (mounted) setState(() => _permission = state);
  }

  Future<void> _onCode(String token) async {
    if (_handled || token.isEmpty) return;
    _handled = true;
    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });

    final qrAuth = context.read<QrAuthService>();
    final auth = context.read<AuthController>();
    final navigator = Navigator.of(context);
    try {
      await qrAuth.redeemQrToken(token);
      await auth.refreshMember();
      navigator.popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = redeemQrErrorMessage(e);
        _phase = _Phase.error;
      });
    }
  }

  void _retry() {
    setState(() {
      _handled = false;
      _error = null;
      _phase = _Phase.scanning;
    });
  }

  void _goToCode() {
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: widget.codeScreenBuilder ?? (_) => const KidEnterCodeScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final footer = _phase == _Phase.loading
        ? null
        : KidLoginLink(
            label: 'QR이 안 보이나요? 번호로 입력하기',
            onPressed: _goToCode,
          );
    return KidLoginLayout(footer: footer, children: [_body()]);
  }

  Widget _body() {
    switch (_permission) {
      case null:
        return const Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
        );
      case CameraPermissionState.canAsk:
        return KidLoginMessage(
          emoji: '📷',
          title: '카메라를 보여주세요',
          description: '부모님 화면의 QR을 찍으려면 카메라를 써도 된다고 알려주세요',
          actionLabel: '카메라 켜기',
          onAction: _requestPermission,
        );
      case CameraPermissionState.blocked:
        return KidLoginMessage(
          emoji: '📷',
          title: '카메라 권한이 꺼져 있어요',
          description: '설정에서 카메라를 켜주세요. 부모님께 도와달라고 해도 좋아요',
          actionLabel: '설정에서 카메라 켜기',
          onAction: widget.permission.openSettings,
        );
      case CameraPermissionState.granted:
        break;
    }

    switch (_phase) {
      case _Phase.loading:
        return const Padding(
          padding: EdgeInsets.only(top: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircularProgressIndicator(color: AppColors.accent),
              SizedBox(height: 16),
              Text('연결하고 있어요...', style: AppTextStyles.cardTitle),
            ],
          ),
        );
      case _Phase.error:
        return KidLoginMessage(
          emoji: '😢',
          title: _error ?? '로그인하지 못했어요',
          description: '부모님께 새 QR을 보여달라고 해주세요',
          actionLabel: '다시 스캔하기',
          onAction: _retry,
        );
      case _Phase.scanning:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('QR로 로그인해요', style: AppTextStyles.pageTitle),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: ColoredBox(
                  color: AppColors.textPrimary,
                  child: widget.scannerBuilder(context, _onCode),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bannerBackground,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: const Text(
                '부모님 화면에 보이는 QR을 카메라에 비춰주세요',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.bannerText,
                ),
              ),
            ),
          ],
        );
    }
  }
}

Widget _defaultScanner(BuildContext context, ValueChanged<String> onCode) {
  return _QrCameraView(onCode: onCode);
}

/// mobile_scanner 실제 카메라 미리보기 (QR 포맷만). 위젯 테스트 대상이 아니다 — 실기기 수동 확인.
class _QrCameraView extends StatefulWidget {
  const _QrCameraView({required this.onCode});

  final ValueChanged<String> onCode;

  @override
  State<_QrCameraView> createState() => _QrCameraViewState();
}

class _QrCameraViewState extends State<_QrCameraView> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: _controller,
      onDetect: (capture) {
        for (final barcode in capture.barcodes) {
          final value = barcode.rawValue;
          if (value != null && value.isNotEmpty) {
            widget.onCode(value);
            return;
          }
        }
      },
      errorBuilder: (context, error) => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            '카메라를 켜지 못했어요. 번호로 입력해주세요',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
