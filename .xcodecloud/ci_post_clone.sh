#!/bin/sh

echo "🔧 [Xcode Cloud] Starting ci_post_clone script..."

# 1. Homebrew 업데이트 및 CocoaPods 설치 (이미 설치돼 있으면 무시됨)
echo "📦 Installing CocoaPods..."
brew install cocoapods

# 2. 최신 xcodeproj 설치 (objectVersion 70 대응)
echo "📦 Installing xcodeproj 1.28.0..."
sudo gem install xcodeproj -v 1.28.0

# 3. pod install 실행
echo "🚀 Running pod install..."
pod install

echo "✅ [Xcode Cloud] ci_post_clone completed!"
