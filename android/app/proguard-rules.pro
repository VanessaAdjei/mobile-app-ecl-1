# Flutter engine and plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# OkHttp and Volley (used by app / ExpressPay)
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class com.squareup.okhttp3.** { *; }
-keep class com.mcxiaoke.volley.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

# Retain generic type information and annotations
-keepattributes Signature
-keepattributes Exceptions
-keepattributes *Annotation*

# ExpressPay SDK (expressPayLibrary AAR)
-keep class com.expresspay.** { *; }
-dontwarn com.expresspay.**

# Prevent stripping of native methods and reflection-used classes
-keepattributes InnerClasses
-keepattributes EnclosingMethod
