#!/bin/bash

# Usage: source setenv.sh <key_name>
# Sources the keys from the specified key directory and sets environment variables for the Kolenu app.
# It must be sourced, not executed, to set the environment variables in the current shell.

# Check if kolenu-workspace exists
WORKSPACE="${KOLENU_WORKSPACE:-../kolenu-workspace}"
if [[ ! -d "$WORKSPACE" ]]; then
    echo "Error: kolenu-workspace not found at $WORKSPACE"
    echo "Make sure you're running this from kolenu-app/ and kolenu-workspace/ is a sibling directory."
    return 1
fi

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script must be sourced, not executed."
    echo "Usage: source setenv.sh <key_name>"
    exit 1
fi

if [[ -z "$1" ]]; then
    echo "Error: key_name is required."
    echo "Usage: source setenv.sh <key_name>"
    return 1
fi

echo ""

echo "Setting environment variables for Kolenu app..."

pushd "$WORKSPACE/tool" > /dev/null
if [[ ! -f "set_keys.sh" ]]; then
    echo "Error: set_keys.sh not found in $WORKSPACE/tool"
    popd > /dev/null
    return 1
fi
source set_keys.sh "$1"
popd > /dev/null

echo ""
