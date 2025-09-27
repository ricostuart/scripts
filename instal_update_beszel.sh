#!/bin/sh

set -e   # exit on error

# =============================
# Paths / Constants
# =============================
BIN_PATH="/usr/local/sbin/beszel-agent"
RC_SYSHOOK="/usr/local/etc/rc.syshook.d/start/90-beszel-agent"
ACTIONS_CONF="/usr/local/opnsense/service/conf/actions.d/actions_beszel-agent.conf"
RC_SCRIPT="/usr/local/etc/rc.beszel-agent"
VERSION_FILE="/usr/local/etc/beszel-agent-version"
TMPDIR="/tmp"

say() {
  echo "[*] $1"
}

error_exit() {
  echo "[ERROR] $1" >&2
  exit 1
}

# =============================
# Detect install status
# =============================
installed=false
if [ -f "$BIN_PATH" ]; then
  installed=true
  say "beszel-agent binary found at $BIN_PATH"
  if pgrep -f "beszel-agent" >/dev/null 2>&1; then
    say "beszel-agent is running"
  else
    say "beszel-agent installed but not running"
  fi
else
  say "beszel-agent is not installed"
fi

if [ "$installed" = false ]; then
  printf "Would you like to install beszel-agent? (y/n): "
  read ans
  case "$ans" in
    y|Y) ;;
    *) say "Aborting."; exit 0 ;;
  esac
fi

# =============================
# Ensure wget is available
# =============================
if ! command -v wget >/dev/null 2>&1; then
  say "wget not present, installing..."
  pkg install -y wget || error_exit "Failed to install wget"
fi

# =============================
# Fetch latest release metadata
# =============================
say "Fetching latest release metadata..."
api_json=$(wget -qO - https://api.github.com/repos/henrygd/beszel/releases/latest) || error_exit "Could not fetch release metadata"

LATEST_URL=$(echo "$api_json" | grep browser_download_url | grep freebsd | grep tar.gz | head -n1 | cut -d '"' -f 4)
if [ -z "$LATEST_URL" ]; then
  error_exit "Could not determine FreeBSD download URL"
fi

LATEST_VERSION=$(echo "$LATEST_URL" | sed -E 's#.*/download/([^/]+)/.*#\1#')
say "Latest version: $LATEST_VERSION"

# Compare to current version if known
if [ -f "$VERSION_FILE" ]; then
  cur=$(cat "$VERSION_FILE")
  if [ "$cur" = "$LATEST_VERSION" ]; then
    say "Already at latest version $cur — nothing to do."
    exit 0
  else
    say "Updating from $cur to $LATEST_VERSION"
  fi
fi

# =============================
# Download archive + checksums
# =============================
ARCHIVE_NAME=$(basename "$LATEST_URL")
say "Downloading $ARCHIVE_NAME ..."
wget -O "$TMPDIR/$ARCHIVE_NAME" "$LATEST_URL" || error_exit "Download failed"

CHECKSUMS_URL=$(echo "$api_json" | grep browser_download_url | grep "${LATEST_VERSION}_checksums.txt" | cut -d '"' -f 4)
if [ -z "$CHECKSUMS_URL" ]; then
  error_exit "Could not find checksum file in release assets"
fi

say "Downloading checksums..."
wget -O "$TMPDIR/checksums.txt" "$CHECKSUMS_URL" || error_exit "Failed to download checksum file"

# =============================
# Verify checksum
# =============================
EXPECTED=$(grep "  $ARCHIVE_NAME" "$TMPDIR/checksums.txt" | awk '{print $1}')
if [ -z "$EXPECTED" ]; then
  error_exit "Checksum for $ARCHIVE_NAME not found in checksums.txt"
fi

ACTUAL=$(sha256 -q "$TMPDIR/$ARCHIVE_NAME" 2>/dev/null || sha256sum "$TMPDIR/$ARCHIVE_NAME" | awk '{print $1}')

say "Expected: $EXPECTED"
say "Actual:   $ACTUAL"

if [ "$EXPECTED" != "$ACTUAL" ]; then
  error_exit "Checksum mismatch for $ARCHIVE_NAME"
else
  say "Checksum OK"
fi

# =============================
# Extract binary
# =============================
say "Extracting archive..."
tar -xzf "$TMPDIR/$ARCHIVE_NAME" -C "$TMPDIR" || error_exit "Extraction failed"
EXTRACTED_BIN=$(find "$TMPDIR" -type f -name "beszel-agent" | head -n1)
[ -z "$EXTRACTED_BIN" ] && error_exit "Could not locate beszel-agent binary"
chmod +x "$EXTRACTED_BIN"

# =============================
# Install binary
# =============================
if [ "$installed" = true ]; then
  say "Stopping existing agent..."
  configctl beszel-agent stop 2>/dev/null || say "Could not stop (maybe not running)"
  rm -f "$BIN_PATH"
fi

say "Installing binary..."
mv "$EXTRACTED_BIN" "$BIN_PATH"
chmod +x "$BIN_PATH"

# Cleanup temp files
rm -f "$TMPDIR/$ARCHIVE_NAME" "$TMPDIR/checksums.txt"

# =============================
# Create integration files
# =============================
if [ ! -f "$RC_SYSHOOK" ]; then
  say "Creating $RC_SYSHOOK"
  mkdir -p "$(dirname "$RC_SYSHOOK")"
  cat > "$RC_SYSHOOK" <<EOF
#!/bin/sh
echo -n "Starting Beszel Agent"
configctl beszel-agent restart
EOF
  chmod +x "$RC_SYSHOOK"
fi

if [ ! -f "$ACTIONS_CONF" ]; then
  say "Creating $ACTIONS_CONF"
  mkdir -p "$(dirname "$ACTIONS_CONF")"
  cat > "$ACTIONS_CONF" <<EOF
[start]
command:sh /usr/local/etc/rc.beszel-agent &
parameters:
type:script
message:Starting beszel-agent
description:Starting beszel-agent service

[restart]
command:sh /usr/local/etc/rc.beszel-agent &
parameters:
type:script
message:Restarting beszel-agent

[stop]
command:ps -ef | pgrep -f "beszel-agent" | xargs kill -9
parameters:
type:script
message:Stopping beszel-agent
EOF
fi

if [ ! -f "$RC_SCRIPT" ]; then
  say "Creating $RC_SCRIPT"
  printf "Enter your Beszel agent key: "
  read USER_KEY
  cat > "$RC_SCRIPT" <<EOF
#!/bin/sh
KEY="$USER_KEY" /usr/local/sbin/beszel-agent
EOF
  chmod +x "$RC_SCRIPT"
fi

# =============================
# Restart + save version
# =============================
say "Restarting configd..."
service configd restart

say "Starting beszel-agent..."
configctl beszel-agent start || error_exit "Failed to start beszel-agent"

echo "$LATEST_VERSION" > "$VERSION_FILE"
say "beszel-agent $LATEST_VERSION installed successfully."
