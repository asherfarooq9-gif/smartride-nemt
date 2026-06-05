import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartride_core/smartride_core.dart' as core;

/// Static Help and FAQ screen. No backend call; the content is bundled.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = <_Faq>[
    _Faq(
      'How do I request an emergency ride?',
      'Tap the red EMERGENCY button on the home screen, describe your '
          'symptoms, and confirm. The nearest available driver is dispatched '
          'automatically.',
    ),
    _Faq(
      'How do I book a ride for later?',
      'On the home screen choose "Book a Ride", pick a pickup time and '
          'destination, and confirm. You can see it later under your rides.',
    ),
    _Faq(
      'Can I track my driver?',
      'Yes. Once a driver accepts your ride, open the ride to see their live '
          'location on the map until they arrive.',
    ),
    _Faq(
      'How do I cancel a ride?',
      'Open the ride from your rides list. Cancellation is available while the '
          'ride is still pending or before the driver arrives.',
    ),
    _Faq(
      'I am also a driver. How do I switch?',
      'Use the menu drawer to switch between the patient and driver portals. '
          'Both run from the same account.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & FAQ')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: core.kSpaceSM),
        children: [
          Container(
            margin: const EdgeInsets.all(core.kSpaceLG),
            padding: const EdgeInsets.all(core.kSpaceLG),
            decoration: BoxDecoration(
              color: core.kEmergencyRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(core.kRadiusLG),
              border: Border.all(color: core.kEmergencyRed.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: core.kEmergencyRed),
                SizedBox(width: core.kSpaceMD),
                Expanded(
                  child: Text(
                    'In a life-threatening emergency, call 1122 immediately.',
                    style: TextStyle(
                      color: core.kEmergencyRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final faq in _faqs)
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
                  style: const TextStyle(color: core.kTextSecondary, height: 1.4),
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
      appBar: AppBar(title: const Text('Contact Us')),
      body: ListView(
        padding: const EdgeInsets.all(core.kSpaceLG),
        children: const [
          Text(
            'We are here to help. For anything that is not an emergency, reach '
            'the SmartRide support team:',
            style: TextStyle(color: core.kTextSecondary, height: 1.4),
          ),
          SizedBox(height: core.kSpaceLG),
          _ContactCard(
            icon: Icons.emergency,
            iconColor: core.kEmergencyRed,
            label: 'Emergency (Rescue 1122)',
            value: '1122',
          ),
          _ContactCard(
            icon: Icons.support_agent,
            label: 'Support hotline',
            value: '+92 51 111 1122',
          ),
          _ContactCard(
            icon: Icons.email_outlined,
            label: 'Email',
            value: 'support@smartride.pk',
          ),
          _ContactCard(
            icon: Icons.schedule,
            label: 'Hours',
            value: 'Support: 8am to 10pm. Emergency dispatch: 24/7.',
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
                  SnackBar(content: Text('$label copied')),
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
