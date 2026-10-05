import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../domain/legal_markdown.dart';

/// Native viewer for the bundled legal Markdown (FE-AUTH-04, FE-LEGAL-01). Works signed in
/// or out because it is pushed imperatively rather than routed through the auth redirect.
class LegalDocumentScreen extends StatefulWidget {
  final LegalDocument document;

  /// Overrides the asset bundle in tests.
  final AssetBundle? bundle;

  const LegalDocumentScreen({super.key, required this.document, this.bundle});

  static Future<void> open(BuildContext context, LegalDocument document) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => LegalDocumentScreen(document: document)),
    );
  }

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late final Future<List<LegalBlock>> _blocks =
      (widget.bundle ?? rootBundle).loadString(widget.document.assetPath).then(parseLegalMarkdown);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TellyColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: TellyColors.backgroundPrimary,
        foregroundColor: TellyColors.textPrimary,
        elevation: 0,
        title: Text(widget.document.title, style: TellyTypography.titleMedium()),
      ),
      body: FutureBuilder<List<LegalBlock>>(
        future: _blocks,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'This document could not be loaded.',
                style: TellyTypography.bodyMedium(color: TellyColors.textSecondary),
              ),
            );
          }
          final blocks = snapshot.data;
          if (blocks == null) {
            return const Center(child: CircularProgressIndicator(color: TellyColors.phosphorLime));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            itemCount: blocks.length,
            itemBuilder: (_, i) => _LegalBlockView(block: blocks[i]),
          );
        },
      ),
    );
  }
}

class _LegalBlockView extends StatelessWidget {
  final LegalBlock block;

  const _LegalBlockView({required this.block});

  @override
  Widget build(BuildContext context) {
    final block = this.block;
    return switch (block) {
      LegalHeading(:final level, :final text) => Padding(
          padding: EdgeInsets.only(top: level == 1 ? 8 : 16, bottom: 8),
          child: Semantics(
            header: true,
            child: _richText(text, level == 1 ? TellyTypography.titleLarge() : TellyTypography.titleMedium()),
          ),
        ),
      LegalParagraph(:final text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _richText(text, TellyTypography.bodyMedium(color: TellyColors.textSecondary)),
        ),
      LegalBullet(:final depth, :final text) => Padding(
          padding: EdgeInsets.only(left: 4.0 + depth * 18, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(depth == 0 ? '•  ' : '◦  ', style: TellyTypography.bodyMedium(color: TellyColors.phosphorLime)),
              Expanded(child: _richText(text, TellyTypography.bodyMedium(color: TellyColors.textSecondary))),
            ],
          ),
        ),
      LegalDivider() => const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(color: TellyColors.strokeSubtle, height: 1),
        ),
    };
  }

  Widget _richText(String text, TextStyle base) {
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          for (final run in parseLegalInlines(text))
            TextSpan(
              text: run.text,
              style: switch (run.style) {
                LegalInlineStyle.plain => null,
                LegalInlineStyle.bold => const TextStyle(fontWeight: FontWeight.w700, color: TellyColors.textPrimary),
                LegalInlineStyle.italic => const TextStyle(fontStyle: FontStyle.italic),
                LegalInlineStyle.code => TellyTypography.scoreMono().copyWith(fontSize: base.fontSize),
              },
            ),
        ],
      ),
    );
  }
}
