#!/bin/bash

# Usage: ./run.sh [flutter_command] [additional_args...]
# Example: ./run.sh run
#          ./run.sh build ios
#          ./run.sh test

set -e

# Default to 'run' if no command provided
FLUTTER_CMD="${1:-run}"
shift || true

# Pass keys via dart-define if loaded; otherwise app uses embedded dummy keys
if [[ -n "$KOLENU_KEY_NAME" && -n "$KOLENU_AUDIO_KEY" && -n "$KOLENU_DOWNLOAD_KEY" ]]; then
    echo "Running flutter $FLUTTER_CMD with key: $KOLENU_KEY_NAME"
    exec flutter "$FLUTTER_CMD" \
        --dart-define=KOLENU_KEY_NAME="$KOLENU_KEY_NAME" \
        --dart-define=KOLENU_AUDIO_KEY="$KOLENU_AUDIO_KEY" \
        --dart-define=KOLENU_DOWNLOAD_KEY="$KOLENU_DOWNLOAD_KEY" \
        "$@"
else
    echo "Running flutter $FLUTTER_CMD (using embedded dummy keys)"
    exec flutter "$FLUTTER_CMD" "$@"
fi
