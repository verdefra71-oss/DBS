#!/bin/bash
set -euo pipefail

# Generate the native iOS host on macOS/GitHub Actions.
flutter create --platforms=ios --org com.dynamique.ballet.studio --project-name dynamique_ballet_studio .
flutter pub get

echo "iOS project generated successfully."
