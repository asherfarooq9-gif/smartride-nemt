import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:patient_app/l10n/l10n.dart';
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
              borderRadius: BorderRadius.circular(core.kRadiusLG),
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
          for (final faq in _faqsFor(context.l10n))
            ExpansionTile(
              leading: const Icon(Icons.help_outline),
              title: Text(faq.question),
              childrenPadding: const EdgeInsets.fromLTRB(
                core.kSpaceLG,
                0,
                core.kSpaceLG,
                core.kSpaceLG,
              ),
              expandedAlignment: Alignment.topLeft,
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  faq.answer,
                  style:
                      const TextStyle(color: core.kTextSecondary, height: 1.4),
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
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.contactTitle)),
      body: ListView(
        padding: const EdgeInsets.all(core.kSpaceLG),
        children: [
          Text(
            context.l10n.contactIntro,
            style: const TextStyle(color: core.kTextSecondary, height: 1.4),
          ),
          const SizedBox(height: core.kSpaceLG),
          _ContactCard(
            icon: Icons.emergency,
            iconColor: core.kEmergencyRed,
            label: context.l10n.contactEmergency,
            value: '1122',
          ),
          _ContactCard(
            icon: Icons.support_agent,
            label: context.l10n.contactHotline,
            value: '+92 51 111 1122',
          ),
          _ContactCard(
            icon: Icons.email_outlined,
            label: context.l10n.contactEmail,
            value: 'support@smartride.pk',
          ),
          _ContactCard(
            icon: Icons.schedule,
            label: context.l10n.contactHours,
            value: context.l10n.contactHoursValue,
            copyable: false,
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.copyable = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: core.kSpaceMD),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? core.kPatientPrimary),
        title: Text(label),
        subtitle: Text(value),
        trailing: copyable ? const Icon(Icons.copy, size: 18) : null,
        onTap: copyable
            ? () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.copiedMessage(label))),
                );
              }
            : null,
      ),
    );
  }
}

class _Faq {
  const _Faq(this.question, this.answer);
  final String question;
  final String answer;
}
