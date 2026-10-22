import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';
import '../widgets/app_logo.dart';
import '../widgets/choice_card.dart';
import '../widgets/form_screen_scaffold.dart';
import 'create_family_screen.dart';
import 'join_family_screen.dart';

/// 시작 화면: "새 가족 만들기" / "초대 코드로 참여하기". RN `app/(auth)/join-choice.tsx`에 대응.
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return FormScreenScaffold(
      showBack: false,
      title: '우리가족톡톡',
      titleWidget: const AppLogo(),
      subtitle: '어떻게 시작할까요?',
      error: auth.lastError == null ? null : '가족 정보를 불러오지 못했어요',
      children: [
        ChoiceCard(
          emoji: '👪',
          title: '새 가족 만들기',
          description: '우리 가족이 처음 쓰는 경우예요. 가족 이름을 정하고 시작해요.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CreateFamilyScreen()),
          ),
        ),
        const SizedBox(height: 12),
        ChoiceCard(
          emoji: '🔗',
          title: '초대 코드로 참여하기',
          description: '다른 보호자님이 만든 가족에 초대 코드로 들어가요.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const JoinFamilyScreen()),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: auth.signOut,
            child: const Text('다른 계정으로 로그인'),
          ),
        ),
      ],
    );
  }
}
