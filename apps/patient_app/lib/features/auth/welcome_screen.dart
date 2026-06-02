import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kWelcomeGradStart, kWelcomeGradEnd],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpaceXL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                // Logo
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, size: 48, color: Colors.white),
                  ),
                ),
                const SizedBox(height: kSpaceXL),
                const Text(
                  'SmartRide',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: kSpaceSM),
                const Text(
                  'Medical transport,\nalways nearby.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: kFontMD,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: kSpaceLG),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: kSpaceLG,
                      vertical: kSpaceXS,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(kRadiusXXL),
                    ),
                    child: const Text(
                      'ISLAMABAD · RAWALPINDI',
                      style: TextStyle(
                        fontSize: kFontXS,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Get started',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: kFontXL,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: kSpaceXS),
                    const Text(
                      'Trusted medical transport for you and your family.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: kFontSM,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: kSpaceXL),
                    SizedBox(
                      height: kMinTapTarget,
                      child: ElevatedButton(
                        onPressed: () => context.push('/signup'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAuthTeal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(kRadiusLG),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Sign Up – It\'s Free',
                          style: TextStyle(
                            fontSize: kFontMD,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: kSpaceMD),
                    SizedBox(
                      height: kMinTapTarget,
                      child: OutlinedButton(
                        onPressed: () => context.push('/login'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(kRadiusLG),
                          ),
                        ),
                        child: const Text(
                          'Log In',
                          style: TextStyle(
                            fontSize: kFontMD,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: kSpaceLG),
                    const Text(
                      'In an emergency, call 1122',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: kFontXS,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: kSpaceXL),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
