#!/bin/bash
# Docker entrypoint: bootstrap config files into the mounted volume, then run hermes.
set -e

HERMES_HOME="/opt/data"
INSTALL_DIR="/opt/hermes"

# Create essential directory structure.
mkdir -p "$HERMES_HOME"/{cron,sessions,logs,hooks,memories,skills,memory}

# .env
if [ ! -f "$HERMES_HOME/.env" ]; then
    cp "$INSTALL_DIR/.env.example" "$HERMES_HOME/.env"
fi

# config.yaml
if [ ! -f "$HERMES_HOME/config.yaml" ]; then
    cp "$INSTALL_DIR/cli-config.yaml.example" "$HERMES_HOME/config.yaml"
fi

# Workspace init files from env vars (Railway deployment).
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

# Sync bundled skills (manifest-based so user edits are preserved)
if [ -d "$INSTALL_DIR/skills" ]; then
    python3 "$INSTALL_DIR/tools/skills_sync.py"
fi

# Run gateway in foreground (correct for Docker/Railway — not systemd)
exec hermes gateway
