# R8/ProGuard keep rules for the SmartRide release build.
# Flutter's own plugin contributes most rules; these guard the libraries this
# app uses against over-aggressive shrinking/obfuscation.

# --- Flutter engine ---
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# --- Firebase (Core, Messaging, Crashlytics) ---
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Crashlytics: keep source/line info so stack traces stay symbolicated.
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# --- Play Core (deferred components / split install referenced by Flutter) ---
-dontwarn com.google.android.play.core.**

# --- Annotations / reflection ---
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
