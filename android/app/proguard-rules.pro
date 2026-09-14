# Google ML Kit Text Recognition references optional language recognizer
# classes (Chinese, Devanagari, Japanese, Korean) generically in its bridge
# code, even though Uangku only uses the Latin recognizer
# (TextRecognitionScript.latin) and doesn't depend on those language
# modules. R8 flags these as "missing classes" during release minification.
# Since these classes are genuinely unused at runtime, it's safe to tell
# R8 to stop warning about them instead of pulling in the extra language
# dependencies just to satisfy the reference.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**