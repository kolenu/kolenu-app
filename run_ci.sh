#!/bin/bash

# 1. Fail immediately if any command fails
set -e

echo "🚀 Starting Local CI Pipeline..."

echo "📦 [1/3] Getting dependencies..."
flutter pub get

echo "🔍 [2/3] Running Static Analysis..."
# This ensures your code follows the strict rules we set
flutter analyze

echo "🧪 [3/3] Running Unit Tests..."
flutter test

echo "✅ Local Pipeline Passed! You can safely push your PR."
