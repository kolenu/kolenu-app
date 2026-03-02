#!/bin/bash

# Usage: ./run.sh [flutter_command] [additional_args...]
# Example: ./run.sh run
#          ./run.sh build ios
#          ./run.sh test

set -e

# Default to 'run' if no command provided
FLUTTER_CMD="${1:-run}"
shift || true

RUN_MODE_FLAG=()
if [[ "$FLUTTER_CMD" == "run" ]]; then
    read -rp "Choose mode [debug/release] (default: debug): " RUN_MODE
    RUN_MODE="${RUN_MODE:-debug}"

    case "$RUN_MODE" in
        release)
            RUN_MODE_FLAG=(--release)
            ;;
        debug)
            RUN_MODE_FLAG=(--debug)
            ;;
        *)
            echo "Invalid mode '$RUN_MODE'. Please choose 'debug' or 'release'."
            exit 1
            ;;
    esac
fi

# No default target: use whatever device VSCode/CLI has selected.
# Pass keys via dart-define if loaded; otherwise app uses embedded dummy keys
if [[ -n "$KOLENU_KEY_NAME" && -n "$KOLENU_AUDIO_KEY" && -n "$KOLENU_DOWNLOAD_KEY" ]]; then
    echo "Running flutter $FLUTTER_CMD with release: $KOLENU_KEY_NAME"
    exec flutter "$FLUTTER_CMD" \
        "${RUN_MODE_FLAG[@]}" \
        --dart-define=KOLENU_KEY_NAME="$KOLENU_KEY_NAME" \
        --dart-define=KOLENU_AUDIO_KEY="$KOLENU_AUDIO_KEY" \
        --dart-define=KOLENU_DOWNLOAD_KEY="$KOLENU_DOWNLOAD_KEY" \
        "$@"
else
    echo "Running flutter $FLUTTER_CMD (using embedded dummy keys)"
    exec flutter "$FLUTTER_CMD" "${RUN_MODE_FLAG[@]}" "$@"
fi
