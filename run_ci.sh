#!/bin/bash

# 1. Fail immediately if any command fails
set -e

echo "🚀 Starting Local CI Pipeline..."

echo "📦 [1/4] Getting dependencies..."
flutter pub get

echo "✨ [2/4] Checking Formatting..."
if ! dart format --output=none --set-exit-if-changed . ; then
    echo "❌ Formatting issues found in the files listed above!"
    echo "💡 Run 'dart format .' to fix them automatically, then try again."
    exit 1
fi
echo "✅ Formatting is perfect!"

echo "🔍 [3/4] Running Static Analysis..."
# This ensures your code follows the strict rules we set
flutter analyze

echo "🧪 [4/4] Running Unit Tests..."
flutter test

echo "✅ Local Pipeline Passed! You can safely push your PR."
