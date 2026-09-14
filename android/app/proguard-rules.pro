# Google ML Kit Text Recognition references optional language recognizer
# classes (Chinese, Devanagari, Japanese, Korean) generically in its bridge
# code, even though Uangku only uses the Latin recognizer
# (TextRecognitionScript.latin) and doesn't depend on those language
# modules. R8 flags these as "missing classes" during release minification.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit and the underlying Google Play Services vision libraries rely on
# reflection internally. -dontwarn alone silences the compile-time warning
# but does NOT guarantee R8 keeps every class those libraries need at
# runtime, which can cause the text recognizer to silently fail only in
# release builds (works fine in debug, since debug builds skip
# minification entirely). These broader -keep rules make sure nothing
# ML Kit actually needs gets stripped.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**