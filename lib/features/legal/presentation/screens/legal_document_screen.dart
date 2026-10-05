import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_screen_header.dart';
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
      appBar: TellySubpageAppBar(title: widget.document.title),
      body: FutureBuilder<List<LegalBlock>>(
        future: _blocks,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'This document could not be loaded.',
                style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context)),
              ),
            );
          }
          final blocks = snapshot.data;
          if (blocks == null) {
            return Center(child: CircularProgressIndicator(color: TellyColors.primaryAccentOf(context)));
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
            child: _richText(context, text, level == 1 ? TellyTypography.titleLarge(color: TellyColors.textPrimaryOf(context)) : TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context))),
          ),
        ),
      LegalParagraph(:final text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _richText(context, text, TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context))),
        ),
      LegalBullet(:final depth, :final text) => Padding(
          padding: EdgeInsets.only(left: 4.0 + depth * 18, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(depth == 0 ? '•  ' : '◦  ', style: TellyTypography.bodyMedium(color: TellyColors.primaryAccentOf(context))),
              Expanded(child: _richText(context, text, TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context)))),
            ],
          ),
        ),
      LegalDivider() => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Divider(color: TellyColors.strokeOf(context), height: 1),
        ),
    };
  }

  Widget _richText(BuildContext context, String text, TextStyle base) {
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          for (final run in parseLegalInlines(text))
            TextSpan(
              text: run.text,
              style: switch (run.style) {
                LegalInlineStyle.plain => null,
                LegalInlineStyle.bold => TextStyle(fontWeight: FontWeight.w700, color: TellyColors.textPrimaryOf(context)),
                LegalInlineStyle.italic => const TextStyle(fontStyle: FontStyle.italic),
                LegalInlineStyle.code => TellyTypography.scoreMono().copyWith(fontSize: base.fontSize),
              },
            ),
        ],
      ),
    );
  }
}
