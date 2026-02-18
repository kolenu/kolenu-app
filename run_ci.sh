#!/bin/bash

# 1. Fail immediately if any command fails
set -e

echo "🚀 Starting Local CI Pipeline..."

echo "🧹 [0/4] Applying Dart formatting..."
dart format .

echo "📦 [1/4] Getting dependencies..."
flutter pub get

echo "✨ [2/4] Checking Formatting..."
# This matches the PR check (it won't fix files, just check them)
dart format --output=none --set-exit-if-changed .

echo "🔍 [3/4] Running Static Analysis..."
# This ensures your code follows the strict rules we set
flutter analyze

echo "🧪 [4/4] Running Unit Tests..."
flutter test

echo "✅ Local Pipeline Passed! You can safely push your PR."
