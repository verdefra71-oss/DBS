#!/bin/bash
set -euo pipefail

# Creates the native iOS host for this Flutter project when running on macOS.
# It intentionally preserves lib/, assets/ and pubspec.yaml.
flutter create --platforms=ios --org com.dynamique.ballet.studio .
flutter pub get

echo "iOS project generated successfully."
echo "For App Store/TestFlight distribution, configure Apple signing in Xcode or CI."
