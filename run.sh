#!/bin/bash

# Usage: ./run.sh [flutter_command] [additional_args...]
# Example: ./run.sh run
#          ./run.sh build ios
#          ./run.sh test

set -e

# Check if keys are loaded
if [[ -z "$KOLENU_KEY_NAME" || -z "$KOLENU_AUDIO_KEY" || -z "$KOLENU_DOWNLOAD_KEY" ]]; then
    echo "Error: Keys not loaded. Please source set_keys.sh first:"
    echo "  source ../tool/set_keys.sh <version>"
    echo "Example: source ../tool/set_keys.sh dummy"
    exit 1
fi

# Default to 'run' if no command provided
FLUTTER_CMD="${1:-run}"
shift || true

echo "Running flutter $FLUTTER_CMD with key: $KOLENU_KEY_NAME"

flutter "$FLUTTER_CMD" \
    --dart-define=KOLENU_KEY_NAME="$KOLENU_KEY_NAME" \
    --dart-define=KOLENU_AUDIO_KEY="$KOLENU_AUDIO_KEY" \
    --dart-define=KOLENU_DOWNLOAD_KEY="$KOLENU_DOWNLOAD_KEY" \
    "$@"
