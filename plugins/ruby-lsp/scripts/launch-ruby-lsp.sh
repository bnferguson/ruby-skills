#!/usr/bin/env bash
# Launcher script for ruby-lsp
# Detects Ruby version manager, activates it, and runs ruby-lsp

set -euo pipefail

# Find ruby-skills detect.sh
DETECT_SCRIPT=$(ls ~/.claude/plugins/cache/*/ruby-skills/*/skills/ruby-version-manager/detect.sh 2>/dev/null | head -1)

if [[ -z "$DETECT_SCRIPT" ]]; then
    echo "Error: ruby-skills plugin not found." >&2
    echo "Install with: claude plugin install ruby-skills" >&2
    exit 1
fi

# Run detection and parse output
# Note: We can't use 'export' with sed because values may contain shell metacharacters
DETECT_OUTPUT=$("$DETECT_SCRIPT")

# Parse key variables we need (use || true to handle missing keys)
ACTIVATION_COMMAND=$(echo "$DETECT_OUTPUT" | grep "^ACTIVATION_COMMAND=" | cut -d= -f2- || true)
NEEDS_USER_CHOICE=$(echo "$DETECT_OUTPUT" | grep "^NEEDS_USER_CHOICE=" | cut -d= -f2 || true)
AVAILABLE_MANAGERS=$(echo "$DETECT_OUTPUT" | grep "^AVAILABLE_MANAGERS=" | cut -d= -f2 || true)

# Handle multiple managers case
if [[ "${NEEDS_USER_CHOICE:-}" == "true" ]]; then
    SET_PREF_SCRIPT="$(dirname "$DETECT_SCRIPT")/set-preference.sh"
    echo "Error: Multiple Ruby version managers detected: ${AVAILABLE_MANAGERS:-}" >&2
    echo "Set preference: $SET_PREF_SCRIPT <manager>" >&2
    echo "Then restart Claude Code." >&2
    exit 1
fi

# Build activation prefix
ACTIVATION="${ACTIVATION_COMMAND:-true}"

# Detect wrapper-style managers (e.g. "mise x --") that expect the command appended directly
IS_WRAPPER=false
if [[ "$ACTIVATION" == *" --" ]]; then
    IS_WRAPPER=true
fi

# Helper: run a command with the version manager activated
run_with_activation() {
    if $IS_WRAPPER; then
        bash -c "$ACTIVATION $*"
    else
        bash -c "$ACTIVATION && $*"
    fi
}

# Check if ruby-lsp is installed, install if needed
if ! run_with_activation "command -v ruby-lsp" &>/dev/null; then
    echo "ruby-lsp: Installing gem..." >&2
    if ! run_with_activation "gem install ruby-lsp" >&2; then
        echo "Error: Failed to install ruby-lsp gem" >&2
        exit 1
    fi
    echo "ruby-lsp: Installation complete." >&2
fi

# Launch ruby-lsp with version manager activation
if $IS_WRAPPER; then
    exec bash -c "$ACTIVATION ruby-lsp"
else
    exec bash -c "$ACTIVATION && exec ruby-lsp"
fi
