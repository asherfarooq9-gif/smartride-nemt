import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartride_core/smartride_core.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(0.0, -1.0),
                end: Alignment(0.0, 1.0),
                transform: GradientRotation(175 * 3.14159265 / 180),
                colors: [kWelcomeGradStart, kWelcomeGradMid, kWelcomeGradEnd],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: kSpaceXL),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 42,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: kSpaceXL),
                        Text(
                          'SmartRide',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: kSpaceSM),
                        Text(
                          'Medical transport, always nearby.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: kFontBody,
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: kSpaceLG),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: kSpaceLG,
                            vertical: kSpaceSM,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(kRadiusPill),
                            border: Border.all(color: kTeal600),
                          ),
                          child: Text(
                            'Islamabad · Rawalpindi',
                            style: GoogleFonts.dmSans(
                              fontSize: kFontSmall,
                              color: kTeal600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(kRadiusSheet),
                    topRight: Radius.circular(kRadiusSheet),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(
                  kSpaceXL,
                  kSpaceXXL,
                  kSpaceXL,
                  0,
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Get started',
                        style: GoogleFonts.dmSans(
                          fontSize: kFontHeading,
                          fontWeight: FontWeight.bold,
                          color: kText900,
                        ),
                      ),
                      const SizedBox(height: kSpaceSM),
                      Text(
                        'Trusted medical transport for you and your family.',
                        style: GoogleFonts.dmSans(
                          fontSize: kFontSmall,
                          color: kText600,
                        ),
                      ),
                      const SizedBox(height: kSpaceXXL),
                      SizedBox(
                        height: kButtonHeight,
                        child: ElevatedButton(
                          onPressed: () => context.push('/signup'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kTeal600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(kRadiusLG),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ).copyWith(
                            shadowColor: WidgetStateProperty.all(
                              kTeal600.withValues(alpha: 0.40),
                            ),
                            elevation: WidgetStateProperty.all(8),
                          ),
                          child: Text(
                            "Sign Up — It's Free",
                            style: GoogleFonts.dmSans(
                              fontSize: kFontBody,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: kSpaceMD),
                      SizedBox(
                        height: kButtonHeight,
                        child: OutlinedButton(
                          onPressed: () => context.push('/login'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kTeal600,
                            side: const BorderSide(color: kTeal600),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(kRadiusLG),
                            ),
                          ),
                          child: Text(
                            'Log In',
                            style: GoogleFonts.dmSans(
                              fontSize: kFontBody,
                              fontWeight: FontWeight.w600,
                              color: kTeal600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: kSpaceLG),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'In an emergency, call ',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: kText400,
                            ),
                          ),
                          Text(
                            '1122',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: kRed600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: kSpaceLG),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
