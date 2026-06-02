import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(kSpaceLG),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.local_hospital, size: 96, color: scheme.primary),
              const SizedBox(height: kSpaceXL),
              Text(
                'SmartRide',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
              ),
              const SizedBox(height: kSpaceXS),
              Text(
                'Emergency & medical transport,\nfor patients and drivers',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: kTextSecondary),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Log In',
                onPressed: () => context.push('/login'),
              ),
              const SizedBox(height: kSpaceLG),
              SizedBox(
                height: kMinTapTarget,
                child: OutlinedButton(
                  onPressed: () => context.push('/signup'),
                  child: const Text('Sign Up'),
                ),
              ),
              const SizedBox(height: kSpaceXXL),
            ],
          ),
        ),
      ),
    );
  }
}
