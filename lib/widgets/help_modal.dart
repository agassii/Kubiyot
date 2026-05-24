import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/language_provider.dart';

class HelpModal extends ConsumerWidget {
  const HelpModal({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => const HelpModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // ── Title bar ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Text('🎲 ', style: TextStyle(fontSize: 18)),
                  Expanded(
                    child: Text(
                      s.helpTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ),
            // ── Scrollable content ─────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: _RulebookRenderer(content: s.rulebookContent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Markdown-like renderer ────────────────────────────────────────────────────

class _RulebookRenderer extends StatelessWidget {
  final String content;
  const _RulebookRenderer({required this.content});

  static const _h1 = TextStyle(
    color: Color(0xFFFFD700),
    fontSize: 20,
    fontWeight: FontWeight.bold,
    height: 1.3,
  );
  static const _h2 = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.bold,
    height: 1.3,
  );
  static const _h3 = TextStyle(
    color: Color(0xFF93C5FD),
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  static const _body = TextStyle(
    color: Color(0xFFCBD5E1),
    fontSize: 13,
    height: 1.5,
  );
  static const _quote = TextStyle(
    color: Color(0xFF94A3B8),
    fontSize: 13,
    fontStyle: FontStyle.italic,
    height: 1.4,
  );
  static const _note = TextStyle(
    color: Color(0xFF64748B),
    fontSize: 12,
    fontStyle: FontStyle.italic,
    height: 1.4,
  );
  static const _bullet = TextStyle(
    color: Color(0xFF3A86FF),
    fontSize: 14,
    height: 1.5,
  );

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context);
    final lines = content.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines) _renderLine(line.trimRight(), dir),
      ],
    );
  }

  Widget _renderLine(String line, TextDirection dir) {
    if (line.isEmpty) return const SizedBox(height: 6);

    if (line.startsWith('---')) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Divider(color: Color(0xFF2A2A4A), thickness: 1),
      );
    }

    if (line.startsWith('# ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: _richText(line.substring(2), _h1, dir),
      );
    }
    if (line.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: _richText(line.substring(3), _h2, dir),
      );
    }
    if (line.startsWith('### ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: _richText(line.substring(4), _h3, dir),
      );
    }
    if (line.startsWith('> ')) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(4),
          border: Border(
            left: dir == TextDirection.rtl
                ? BorderSide.none
                : const BorderSide(color: Color(0xFF3A86FF), width: 3),
            right: dir == TextDirection.rtl
                ? const BorderSide(color: Color(0xFF3A86FF), width: 3)
                : BorderSide.none,
          ),
        ),
        child: _richText(line.substring(2), _quote, dir),
      );
    }
    if (line.startsWith('  * ')) {
      return Padding(
        padding: EdgeInsetsDirectional.only(start: 16, top: 2, bottom: 2),
        child: Row(
          textDirection: dir,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('◦ ', style: _bullet, textDirection: dir),
            Expanded(child: _richText(line.trimLeft().substring(2), _body, dir)),
          ],
        ),
      );
    }
    if (line.startsWith('* ')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          textDirection: dir,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• ', style: _bullet, textDirection: dir),
            Expanded(child: _richText(line.substring(2), _body, dir)),
          ],
        ),
      );
    }
    if (line.startsWith('*(') || line.startsWith('*(Note')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: _richText(line, _note, dir),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: _richText(line, _body, dir),
    );
  }

  Widget _richText(String text, TextStyle base, TextDirection dir) {
    if (!text.contains('**')) {
      return Text(text, style: base, textDirection: dir);
    }
    final parts = text.split('**');
    final spans = <InlineSpan>[
      for (int i = 0; i < parts.length; i++)
        TextSpan(
          text: parts[i],
          style: i.isOdd
              ? base.copyWith(
                  fontWeight: FontWeight.bold,
                  color: base.color?.withValues(alpha: 1.0) ??
                      const Color(0xFFE2E8F0),
                )
              : base,
        ),
    ];
    return RichText(
      text: TextSpan(children: spans),
      textDirection: dir,
    );
  }
}
