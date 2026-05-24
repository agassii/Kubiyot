import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_strings.dart';
import '../providers/language_provider.dart';

class LangToggle extends ConsumerWidget {
  const LangToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHe = ref.watch(languageProvider) == AppLanguage.he;
    return GestureDetector(
      onTap: () => ref.read(languageProvider.notifier).toggle(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2A2A4A)),
        ),
        child: Text(
          isHe ? 'EN' : 'עב',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
