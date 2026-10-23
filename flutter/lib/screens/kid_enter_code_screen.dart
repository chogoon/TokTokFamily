import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/qr_auth_service.dart';
import '../state/auth_controller.dart';
import '../theme/app_colors.dart';
import '../utils/api_error_messages.dart';
import '../utils/short_code.dart';
import '../widgets/kid_login_message.dart';
import 'kid_scan_qr_screen.dart';

/// 아이 기기: 부모님 화면의 6자리 번호를 입력해 로그인. RN `app/(auth)/enter-code.tsx`에 대응.
/// 6자리가 채워지면 자동으로 제출한다.
class KidEnterCodeScreen extends StatefulWidget {
  const KidEnterCodeScreen({super.key, this.scanScreenBuilder});

  /// "QR로 스캔하기" 대상 화면 (테스트 주입용). 기본은 [KidScanQrScreen].
  final WidgetBuilder? scanScreenBuilder;

  @override
  State<KidEnterCodeScreen> createState() => _KidEnterCodeScreenState();
}

class _KidEnterCodeScreenState extends State<KidEnterCodeScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;

  /// 같은 6자리로 중복 제출하지 않도록 막는다.
  bool _handled = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (isCompleteShortCode(value)) _submit(value);
  }

  Future<void> _submit(String code) async {
    if (_handled || !isCompleteShortCode(code)) return;
    _handled = true;
    setState(() {
      _loading = true;
      _error = null;
    });

    final qrAuth = context.read<QrAuthService>();
    final auth = context.read<AuthController>();
    final navigator = Navigator.of(context);
    try {
      await qrAuth.redeemShortCode(code);
      await auth.refreshMember();
      navigator.popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = redeemShortCodeErrorMessage(e);
        _loading = false;
      });
    }
  }

  void _retry() {
    _code.clear();
    setState(() {
      _handled = false;
      _error = null;
    });
  }

  void _goToScan() {
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: widget.scanScreenBuilder ?? (_) => const KidScanQrScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final footer = _loading
        ? null
        : KidLoginLink(label: '📷 QR로 스캔하기', onPressed: _goToScan);

    if (_error != null) {
      return KidLoginLayout(footer: footer, children: [
        KidLoginMessage(
          emoji: '😢',
          title: _error!,
          description: '부모님 화면의 번호를 다시 확인해주세요',
          actionLabel: '다시 입력하기',
          onAction: _retry,
        ),
      ]);
    }

    return KidLoginLayout(footer: footer, children: [
      const KidLoginMessage(
        emoji: '🔢',
        title: '번호로 로그인해요',
        description: '부모님 화면에 보이는 6자리 번호를 입력해주세요',
      ),
      const SizedBox(height: 24),
      TextField(
        controller: _code,
        autofocus: true,
        enabled: !_loading,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        maxLength: shortCodeLength,
        inputFormatters: const [_ShortCodeFormatter()],
        buildCounter: _noCounter,
        onChanged: _onChanged,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: 8,
          color: AppColors.textPrimary,
        ),
        decoration: const InputDecoration(
          hintText: '000000',
          contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        ),
      ),
      if (_loading) ...[
        const SizedBox(height: 20),
        const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      ],
    ]);
  }
}

/// 붙여넣기("482 913") 등 어떤 입력이든 숫자만 최대 6자리로 정제한다.
class _ShortCodeFormatter extends TextInputFormatter {
  const _ShortCodeFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final sanitized = sanitizeShortCodeInput(newValue.text);
    if (sanitized == newValue.text) return newValue;
    return TextEditingValue(
      text: sanitized,
      selection: TextSelection.collapsed(offset: sanitized.length),
    );
  }
}

Widget? _noCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) =>
    null;
