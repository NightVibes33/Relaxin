#!/usr/bin/env sh
set -eu
MODE="box"
API_URL="https://ascii.dev"
CHANNEL="ascii-prod"
INSTALL_DIR="$HOME/.ascii/bin"

case "$(uname -s)" in
  Linux) OS="linux" ;;
  Darwin) OS="darwin" ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

case "$(uname -m)" in
  x86_64|amd64) ARCH="x64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

URL="$API_URL/api/box/cli/download?platform=$OS-$ARCH&channel=$CHANNEL"
mkdir -p "$INSTALL_DIR"
TMP="$(mktemp)"
curl -fsSL "$URL" -o "$TMP"
chmod +x "$TMP"
mv "$TMP" "$INSTALL_DIR/$MODE"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ascii/$MODE"
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_DIR/config.json" <<EOF
{
  "api_url": "$API_URL",
  "channel": "$CHANNEL"
}
EOF

CURRENT_ENV_NAME="BOX_CURRENT_ID"
if [ "$MODE" = "box-dev" ]; then CURRENT_ENV_NAME="BOX_DEV_CURRENT_ID"; fi
if [ "$MODE" = "box-staging" ]; then CURRENT_ENV_NAME="BOX_STAGING_CURRENT_ID"; fi
SHELL_NAME="$(basename "$SHELL" 2>/dev/null || echo sh)"
PROFILE="$HOME/.profile"
if [ "$SHELL_NAME" = "zsh" ]; then PROFILE="$HOME/.zshrc"; fi
if [ "$SHELL_NAME" = "bash" ]; then PROFILE="$HOME/.bashrc"; fi
if [ "$SHELL_NAME" = "bash" ] || [ "$SHELL_NAME" = "zsh" ]; then
if [ -f "$PROFILE" ]; then
  TMP_PROFILE="$(mktemp)"
  sed "/# ASCII BOX SHELL INTEGRATION START $MODE/,/# ASCII BOX SHELL INTEGRATION END $MODE/d" "$PROFILE" > "$TMP_PROFILE"
  cat "$TMP_PROFILE" > "$PROFILE"
  rm -f "$TMP_PROFILE"
fi
cat >> "$PROFILE" <<EOF

# ASCII BOX SHELL INTEGRATION START $MODE
$MODE() {
EOF
cat >> "$PROFILE" <<'EOF'
  current_file=$(mktemp)
  old_current_file=${BOX_CURRENT_ID_FILE-}
  export BOX_CURRENT_ID_FILE="$current_file"
EOF
cat >> "$PROFILE" <<EOF
  command "$INSTALL_DIR/$MODE" "\$@"
EOF
cat >> "$PROFILE" <<'EOF'
  box_status=$?
  if [ "$box_status" -eq 0 ]; then
    case "${1:-}" in
      new|start|fork)
        if [ -s "$current_file" ]; then
          current_id=$(tr -d '[:space:]' < "$current_file")
EOF
cat >> "$PROFILE" <<EOF
          if [ -n "\$current_id" ]; then export $CURRENT_ENV_NAME="\$current_id"; fi
EOF
cat >> "$PROFILE" <<'EOF'
        fi
        ;;
    esac
  fi
  if [ -n "$old_current_file" ]; then export BOX_CURRENT_ID_FILE="$old_current_file"; else unset BOX_CURRENT_ID_FILE; fi
  rm -f "$current_file"
  return "$box_status"
}
EOF
cat >> "$PROFILE" <<EOF
# ASCII BOX SHELL INTEGRATION END $MODE
EOF
echo "Updated $MODE shell integration in $PROFILE."
else
echo "Shell integration for 'current' is available for bash and zsh. Use explicit box IDs in $SHELL_NAME."
fi

echo "Installed $MODE to $INSTALL_DIR/$MODE"
case ":$PATH:" in
  *":$INSTALL_DIR:"*)
    echo "$INSTALL_DIR is already on PATH."
    echo "Run: $MODE onboard"
    ;;
  *)
    echo ""
    echo "$INSTALL_DIR is not on PATH yet."
    echo "For this terminal, run:"
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
    echo "  $MODE onboard"
    echo ""
    echo "To make it permanent, run:"
    echo "  printf '\nexport PATH=\"$INSTALL_DIR:\$PATH\"\n' >> $PROFILE"
    echo "  source $PROFILE"
    echo "  $MODE onboard"
    ;;
esac
echo ""
if [ -r /dev/tty ]; then
  "$INSTALL_DIR/$MODE" onboard < /dev/tty
else
  "$INSTALL_DIR/$MODE" onboard
fi
