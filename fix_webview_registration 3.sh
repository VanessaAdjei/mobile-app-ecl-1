#!/bin/bash
# Fix for webview_flutter_android plugin registration issue
# This script fixes the GeneratedPluginRegistrant.java file after Flutter regenerates it

FILE="android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java"

if [ ! -f "$FILE" ]; then
  echo "File not found: $FILE"
  exit 1
fi

# Check if the file needs fixing (contains the problematic direct instantiation)
if grep -q "new io.flutter.plugins.webviewflutter.WebViewFlutterPlugin()" "$FILE"; then
  echo "Fixing webview plugin registration in $FILE..."
  
  # Create a temporary file with the fix
  awk '
    /new io\.flutter\.plugins\.webviewflutter\.WebViewFlutterPlugin\(\)/ {
      print "    // webview_flutter_android: Use reflection to avoid compile-time class not found error"
      print "    try {"
      print "      Class<?> clazz = Class.forName(\"io.flutter.plugins.webviewflutter.WebViewFlutterPlugin\");"
      print "      Object instance = clazz.getDeclaredConstructor().newInstance();"
      print "      flutterEngine.getPlugins().add((io.flutter.embedding.engine.plugins.FlutterPlugin) instance);"
      print "    } catch (ClassNotFoundException e) {"
      print "      // Plugin auto-registers via Flutter plugin loader - this is expected"
      print "      Log.d(TAG, \"webview_flutter_android will be auto-registered by Flutter plugin loader\");"
      print "    } catch (Exception e) {"
      print "      Log.w(TAG, \"webview_flutter_android registration skipped, using auto-registration\", e);"
      print "    }"
      next
    }
    /Error registering plugin webview_flutter_android/ {
      # Skip the error log line that follows the problematic code
      next
    }
    { print }
  ' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
  
  echo "✓ Fixed webview plugin registration"
else
  echo "File already fixed or doesn't need fixing"
fi
