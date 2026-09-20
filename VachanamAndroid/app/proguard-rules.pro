# Add project specific ProGuard rules here.
-dontwarn **
-keep class com.tom_roush.pdfbox.** { *; }
-keep class ai.onnxruntime.** { *; }
-keep class androidx.media3.** { *; }
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory { *; }
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler { *; }

