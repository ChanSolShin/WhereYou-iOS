#!/bin/sh

echo "🔧 ci_post_clone: Installing CocoaPods dependencies..."

brew install cocoapods || echo "✅ CocoaPods already installed"

cd "$CI_WORKSPACE" || exit 1

if [ -f "Podfile" ]; then
  pod install
  echo "✅ pod install completed"
else
  echo "❌ Podfile not found in $CI_WORKSPACE"
  exit 1
fi
