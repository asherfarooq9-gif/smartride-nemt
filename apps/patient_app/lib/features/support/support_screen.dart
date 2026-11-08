import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:patient_app/l10n/l10n.dart';
import 'package:patient_app/shared/apple_list.dart';
import 'package:smartride_core/smartride_core.dart' as core;

/// Static Help and FAQ screen. No backend call; the content is bundled.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static List<_Faq> _faqsFor(AppLocalizations l) => [
        _Faq(l.faq1q, l.faq1a),
        _Faq(l.faq2q, l.faq2a),
        _Faq(l.faq3q, l.faq3a),
        _Faq(l.faq4q, l.faq4a),
        _Faq(l.faq5q, l.faq5a),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.helpTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: core.kSpaceSM),
        children: [
          Container(
            margin: const EdgeInsets.all(core.kSpaceLG),
            padding: const EdgeInsets.all(core.kSpaceLG),
            decoration: BoxDecoration(
              color: core.kEmergencyRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(core.kRadiusMD),
              border:
                  Border.all(color: core.kEmergencyRed.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: core.kEmergencyRed),
                const SizedBox(width: core.kSpaceMD),
                Expanded(
                  child: Text(
                    context.l10n.helpBanner,
                    style: const TextStyle(
                      color: core.kEmergencyRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppleSection(
            dividerIndent: core.kSpaceLG,
            children: [
              for (final faq in _faqsFor(context.l10n))
                ExpansionTile(
                  // No lines of its own: the section draws the dividers.
                  shape: const Border(),
                  collapsedShape: const Border(),
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: core.kSpaceLG,
                  ),
                  title: Text(
                    faq.question,
                    style: const TextStyle(fontSize: core.kFontBody),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(
                    core.kSpaceLG,
                    0,
                    core.kSpaceLG,
                    core.kSpaceLG,
                  ),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      faq.answer,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Static Contact Us screen. Contact rows can be copied to the clipboard.
class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.contactTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: core.kSpaceSM),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              core.kSpaceXL,
              core.kSpaceSM,
              core.kSpaceXL,
              core.kSpaceXS,
            ),
            child: Text(
              l10n.contactIntro,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
          AppleSection(
            dividerIndent: appleIconDividerIndent,
            children: [
              _contactRow(
                context,
                icon: Icons.emergency,
                iconColor: core.kEmergencyRed,
                label: l10n.contactEmergency,
                value: '1122',
              ),
              _contactRow(
                context,
                icon: Icons.support_agent,
                label: l10n.contactHotline,
                value: '+92 51 111 1122',
              ),
              _contactRow(
                context,
                icon: Icons.email_outlined,
                label: l10n.contactEmail,
                value: 'support@smartride.pk',
              ),
              _contactRow(
                context,
                icon: Icons.schedule,
                label: l10n.contactHours,
                value: l10n.contactHoursValue,
                copyable: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A contact line. Tapping a copyable one puts its value on the clipboard.
  Widget _contactRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? iconColor,
    bool copyable = true,
  }) {
    final hint = Theme.of(context).brightness == Brightness.dark
        ? core.kDarkText3
        : core.kText400;
    return AppleRow(
      icon: icon,
      iconColor: iconColor,
      title: label,
      subtitle: value,
      trailing: copyable
          ? Icon(Icons.copy_rounded,
              size: 18, color: hint.withValues(alpha: 0.6))
          : null,
      onTap: copyable
          ? () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.copiedMessage(label))),
              );
            }
          : null,
    );
  }
}

class _Faq {
  const _Faq(this.question, this.answer);
  final String question;
  final String answer;
}
