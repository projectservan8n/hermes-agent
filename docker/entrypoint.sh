#!/bin/bash
# Docker entrypoint: bootstrap config files into the mounted volume, then run hermes gateway.
set -e

HERMES_HOME="/opt/data"
INSTALL_DIR="/opt/hermes"

# Create essential directory structure.
mkdir -p "$HERMES_HOME"/{cron,sessions,logs,hooks,memories,skills,memory}

# .env — copy example if missing
if [ ! -f "$HERMES_HOME/.env" ]; then
    cp "$INSTALL_DIR/.env.example" "$HERMES_HOME/.env"
fi

# Inject Railway environment variables into .env (upsert pattern)
inject_env() {
  local KEY="$1"
  local VAL="$2"
  if [ -n "$VAL" ]; then
    # Remove any existing line (commented or uncommented) for this key, then append
    sed -i "/^#*\s*${KEY}=/d" "$HERMES_HOME/.env"
    echo "${KEY}=${VAL}" >> "$HERMES_HOME/.env"
  fi
}

inject_env "TELEGRAM_BOT_TOKEN"      "$TELEGRAM_BOT_TOKEN"
inject_env "TELEGRAM_ALLOWED_USERS"  "$TELEGRAM_ALLOWED_USERS"
inject_env "TELEGRAM_HOME_CHANNEL"   "$TELEGRAM_HOME_CHANNEL"
inject_env "TELEGRAM_HOME_CHANNEL_NAME" "$TELEGRAM_HOME_CHANNEL_NAME"
inject_env "OPENROUTER_API_KEY"      "$OPENROUTER_API_KEY"
inject_env "GITHUB_TOKEN"            "$GITHUB_TOKEN"
inject_env "ELEVENLABS_API_KEY"      "$ELEVENLABS_API_KEY"

# config.yaml
if [ ! -f "$HERMES_HOME/config.yaml" ]; then
    cp "$INSTALL_DIR/cli-config.yaml.example" "$HERMES_HOME/config.yaml"
fi

# Workspace init files from env vars (Railway deployment — base64 encoded)
declare -A WORKSPACE_FILES=(
  ["SOUL_MD"]="SOUL.md"
  ["MEMORY_MD"]="MEMORY.md"
  ["TOOLS_MD"]="TOOLS.md"
  ["USER_MD"]="USER.md"
  ["AGENTS_MD"]="AGENTS.md"
  ["IDENTITY_MD"]="IDENTITY.md"
  ["HEARTBEAT_MD"]="HEARTBEAT.md"
)

for VAR_KEY in "${!WORKSPACE_FILES[@]}"; do
  FILE_NAME="${WORKSPACE_FILES[$VAR_KEY]}"
  ENV_VAR="WORKSPACE_INIT_${VAR_KEY}"
  if [ -n "${!ENV_VAR}" ] && [ ! -f "$HERMES_HOME/$FILE_NAME" ]; then
    echo "[init] Writing $FILE_NAME from env var..."
    echo "${!ENV_VAR}" | base64 -d > "$HERMES_HOME/$FILE_NAME"
  fi
done

# Fallback: copy default SOUL.md from install dir if still missing
if [ ! -f "$HERMES_HOME/SOUL.md" ]; then
    cp "$INSTALL_DIR/docker/SOUL.md" "$HERMES_HOME/SOUL.md"
fi

# Sync bundled skills
if [ -d "$INSTALL_DIR/skills" ]; then
    python3 "$INSTALL_DIR/tools/skills_sync.py"
fi

echo "[init] Starting Hermes gateway (foreground)..."
exec hermes gateway
