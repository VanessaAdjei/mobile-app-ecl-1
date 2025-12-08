#!/bin/bash
# Fix for webview_flutter_android plugin registration issue
# This script fixes the GeneratedPluginRegistrant.java file after Flutter regenerates it

FILE="android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java"

if [ -f "$FILE" ]; then
  sed -i '' 's/new io\.flutter\.plugins\.webviewflutter\.WebViewFlutterPlugin()/Class.forName("io.flutter.plugins.webviewflutter.WebViewFlutterPlugin").getDeclaredConstructor().newInstance()/g' "$FILE"
  sed -i '' 's/flutterEngine\.getPlugins()\.add(new io\.flutter\.plugins\.webviewflutter\.WebViewFlutterPlugin());/Class<?> clazz = Class.forName("io.flutter.plugins.webviewflutter.WebViewFlutterPlugin"); Object instance = clazz.getDeclaredConstructor().newInstance(); flutterEngine.getPlugins().add((io.flutter.embedding.engine.plugins.FlutterPlugin) instance);/g' "$FILE"
  echo "Fixed webview plugin registration in $FILE"
else
  echo "File not found: $FILE"
fi

