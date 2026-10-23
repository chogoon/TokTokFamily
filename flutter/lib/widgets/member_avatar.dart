import 'package:flutter/material.dart';

import '../models/member.dart';
import '../theme/app_colors.dart';
import '../utils/kid_palette.dart';

/// 구성원 아바타: members.color 배경 원 + avatar 이모지. 값이 없으면 테두리 색 + 기본 이모지.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.member, this.size = 40});

  final Member member;
  final double size;

  @override
  Widget build(BuildContext context) {
    final emoji = member.avatar ?? (member.isParent ? '👤' : '🙂');
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: parseHexColor(member.color) ?? AppColors.border,
        shape: BoxShape.circle,
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
    );
  }
}
