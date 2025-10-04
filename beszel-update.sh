#!/bin/sh
set -e

# =============================
# Config
# =============================
BIN_PATH="/usr/local/sbin/beszel-agent"
RC_SYSHOOK="/usr/local/etc/rc.syshook.d/start/90-beszel-agent"
ACTIONS_CONF="/usr/local/opnsense/service/conf/actions.d/actions_beszel-agent.conf"
RC_SCRIPT="/usr/local/etc/rc.beszel-agent"
VERSION_FILE="/usr/local/etc/beszel-agent-version"

say() { echo "[*] $1"; }
error_exit() { echo "[ERROR] $1" >&2; exit 1; }

WORKDIR="$(mktemp -d /tmp/beszel.XXXXXX)" || error_exit "mktemp failed"
trap 'rc=$?; [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; exit $rc' EXIT

# =============================
# Detect arch
# =============================
ARCH="$(uname -m)"
case "$ARCH" in
  amd64) ARCH_FILE="freebsd_amd64" ;;
  arm64|aarch64) ARCH_FILE="freebsd_arm64" ;;
  *) error_exit "Unsupported architecture: $ARCH" ;;
esac

say "Detected architecture: $ARCH → will fetch $ARCH_FILE build"

# =============================
# Detect installed / running
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
# Ensure wget
# =============================
if ! command -v wget >/dev/null 2>&1; then
  say "wget missing; installing..."
  pkg install -y wget || error_exit "Failed to install wget"
fi

# =============================
# Get latest release metadata
# =============================
say "Fetching latest release metadata from GitHub..."
api_json="$(wget -qO - https://api.github.com/repos/henrygd/beszel/releases/latest)" || error_exit "Failed to fetch GitHub release metadata"

LATEST_URL=$(printf '%s\n' "$api_json" | grep browser_download_url | grep "$ARCH_FILE" | grep -E '\.tar\.gz' | head -n1 | cut -d '"' -f 4)
[ -n "$LATEST_URL" ] || error_exit "Could not determine FreeBSD $ARCH_FILE download URL"

LATEST_TAG=$(echo "$LATEST_URL" | sed -E 's#.*/download/([^/]+)/.*#\1#')
LATEST_VERSION=$(printf '%s' "$LATEST_TAG" | sed 's/^v//')   # strip leading v

say "Latest release tag: $LATEST_TAG"
say "Using version string (no leading v): $LATEST_VERSION"

if [ -f "$VERSION_FILE" ]; then
  cur="$(cat "$VERSION_FILE")"
  if [ "$cur" = "$LATEST_VERSION" ]; then
    say "Already at latest version ($cur). Nothing to do."
    exit 0
  fi
  say "Current version $cur → will update to $LATEST_VERSION"
fi

ARCHIVE_NAME="$(basename "$LATEST_URL")"
say "Will download archive: $ARCHIVE_NAME"

# =============================
# Download archive + checksums
# =============================
say "Downloading archive ..."
wget -qO "$WORKDIR/$ARCHIVE_NAME" "$LATEST_URL" || error_exit "Failed to download $LATEST_URL"

CHECKSUM_FILENAME="beszel_${LATEST_VERSION}_checksums.txt"
CHECKSUMS_URL=$(printf '%s\n' "$api_json" | grep browser_download_url | grep -F "$CHECKSUM_FILENAME" | cut -d '"' -f 4 || true)
[ -n "$CHECKSUMS_URL" ] || error_exit "Could not locate checksum file $CHECKSUM_FILENAME"

say "Downloading checksum file ..."
wget -qO "$WORKDIR/checksums.txt" "$CHECKSUMS_URL" || error_exit "Failed to download checksum file"

# =============================
# Parse checksum file (match exact filename)
# =============================
EXPECTED="$(awk -v name="$ARCHIVE_NAME" '{
  for(i=1;i<=NF;i++){
    if($i==name){ if(i>1){print $(i-1); exit} }
  }
}' "$WORKDIR/checksums.txt")"

[ -n "$EXPECTED" ] || error_exit "Could not extract expected checksum for $ARCHIVE_NAME"

if command -v sha256 >/dev/null 2>&1; then
  ACTUAL="$(sha256 -q "$WORKDIR/$ARCHIVE_NAME")"
else
  ACTUAL="$(sha256sum "$WORKDIR/$ARCHIVE_NAME" | awk '{print $1}')"
fi

say "Expected: $EXPECTED"
say "Actual:   $ACTUAL"
[ "$EXPECTED" = "$ACTUAL" ] || error_exit "Checksum mismatch for $ARCHIVE_NAME — aborting"

say "Checksum OK"

# =============================
# Extract binary
# =============================
say "Extracting archive..."
tar -xzf "$WORKDIR/$ARCHIVE_NAME" -C "$WORKDIR" || error_exit "Extraction failed"
EXTRACTED_BIN="$(find "$WORKDIR" -type f -name 'beszel-agent' -print -quit || true)"
[ -n "$EXTRACTED_BIN" ] || error_exit "Could not locate extracted 'beszel-agent' binary"
chmod +x "$EXTRACTED_BIN"

# =============================
# Install / update binary
# =============================
if [ -f "$BIN_PATH" ]; then
  say "Stopping existing beszel-agent (if running) ..."
  configctl beszel-agent stop 2>/dev/null || say "Could not stop (maybe not running)"
  say "Backing up current binary to ${BIN_PATH}.old"
  mv -f "$BIN_PATH" "${BIN_PATH}.old" || say "Warning: backup failed"
fi

say "Installing new binary to $BIN_PATH"
mv "$EXTRACTED_BIN" "$BIN_PATH"
chmod +x "$BIN_PATH"

# =============================
# Ensure integration files
# =============================
if [ ! -f "$RC_SYSHOOK" ]; then
  say "Creating $RC_SYSHOOK"
  mkdir -p "$(dirname "$RC_SYSHOOK")"
  cat > "$RC_SYSHOOK" <<'EOF'
#!/bin/sh
echo -n "Starting Beszel Agent"
configctl beszel-agent restart
EOF
  chmod +x "$RC_SYSHOOK"
fi

if [ ! -f "$ACTIONS_CONF" ]; then
  say "Creating $ACTIONS_CONF"
  mkdir -p "$(dirname "$ACTIONS_CONF")"
  cat > "$ACTIONS_CONF" <<'EOF'
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

# rc script: preserve KEY if present
if [ ! -f "$RC_SCRIPT" ]; then
  say "Creating $RC_SCRIPT"
  printf "Enter your Beszel agent key: "
  read USER_KEY
  cat > "$RC_SCRIPT" <<EOF
#!/bin/sh
KEY="$USER_KEY" /usr/local/sbin/beszel-agent
EOF
  chmod +x "$RC_SCRIPT"
else
  say "Using existing $RC_SCRIPT (KEY preserved)"
fi

# =============================
# Restart services and start agent
# =============================
say "Restarting configd..."
service configd restart

say "Starting beszel-agent..."
if ! configctl beszel-agent start; then
  say "❌ New version failed to start — rolling back..."
  if [ -f "${BIN_PATH}.old" ]; then
    mv -f "${BIN_PATH}.old" "$BIN_PATH"
    chmod +x "$BIN_PATH"
    service configd restart
    if configctl beszel-agent start; then
      error_exit "Rollback successful — reverted to previous version."
    else
      error_exit "Rollback attempted but agent still failed."
    fi
  else
    error_exit "No backup available for rollback."
  fi
fi

echo "$LATEST_VERSION" > "$VERSION_FILE"
say "✅ beszel-agent $LATEST_VERSION installed successfully."

# =============================
# Ensure weekly cron job in /etc/crontab
# =============================
CRON_LINE="15 3 * * 0  root  /usr/local/sbin/beszel-update.sh >> /var/log/beszel-agent-update.log 2>&1"

say "Ensuring weekly cron job exists in /etc/crontab..."
if grep -Fq "/usr/local/sbin/beszel-update.sh" /etc/crontab; then
  say "Cron job already present."
else
  echo "$CRON_LINE" >> /etc/crontab
  say "Cron job added: will run Sundays at 03:15"
fi

exit 0
