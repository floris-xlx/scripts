#!/usr/bin/env bash
set -euo pipefail

# colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m" # reset

error_exit() {
  echo -e "${RED}ERROR:${NC} $1"
  exit 1
}

info() {
  echo -e "${BLUE}INFO:${NC} $1"
}

success() {
  echo -e "${GREEN}SUCCESS:${NC} $1"
}

warn() {
  echo -e "${YELLOW}WARN:${NC} $1"
}

# check dependencies
command -v git >/dev/null || {
  info "git not found, installing..."
  sudo apt-get update && sudo apt-get install -y git || error_exit "failed to install git"
}

command -v docker >/dev/null || error_exit "docker not found, install: https://docs.docker.com/engine/install/"

command -v docker compose >/dev/null || error_exit "docker compose plugin not found, install it"

# clone repo
if [ ! -d "trigger.dev" ]; then
  info "Cloning Trigger.dev repository..."
  git clone --depth=1 https://github.com/triggerdotdev/trigger.dev || error_exit "git clone failed"
else
  warn "trigger.dev directory already exists, skipping clone"
fi

cd trigger.dev/hosting/docker || error_exit "cannot cd into hosting/docker"

# create .env
if [ ! -f ".env" ]; then
  cp .env.example .env || error_exit "failed to copy .env.example"
  warn ".env file created, edit it to configure environment variables"
else
  info ".env already exists"
fi

# start combined stack
info "Starting combined webapp + worker stack..."
docker compose -f webapp/docker-compose.yml -f worker/docker-compose.yml up -d || error_exit "docker compose up failed"

# wait for worker token and magic link
info "Waiting for worker token and magic login link (timeout ~2.5 min)..."
TOKEN=""
MAGIC=""
for i in {1..30}; do
  LOGS=$(docker compose -f webapp/docker-compose.yml logs webapp 2>&1 || true)

  if [ -z "$TOKEN" ]; then
    TOKEN=$(echo "$LOGS" | grep -A3 "Trigger.dev Bootstrap - Worker Token" \
      | grep -oE 'tr_wgt_[A-Za-z0-9]+$' || true)
  fi

  if [ -z "$MAGIC" ]; then
    MAGIC=$(echo "$LOGS" | grep -oE 'http://localhost:8030/auth/magic\?token=[A-Za-z0-9._-]+' | head -n1 || true)
  fi

  [ -n "$TOKEN" ] && [ -n "$MAGIC" ] && break
  sleep 5
done

# process worker token
if [ -n "$TOKEN" ]; then
  success "Worker token detected"
  echo -e "${BLUE}$TOKEN${NC}"
  if grep -q "^TRIGGER_WORKER_TOKEN=" .env; then
    sed -i "s|^TRIGGER_WORKER_TOKEN=.*|TRIGGER_WORKER_TOKEN=$TOKEN|" .env
  else
    echo "TRIGGER_WORKER_TOKEN=$TOKEN" >> .env
  fi
  info "Token added to .env, restarting worker..."
  (cd worker && docker compose down && docker compose up -d) || error_exit "failed to restart worker"
else
  warn "Worker token not found after timeout. Check manually with:"
  echo "  docker compose -f webapp/docker-compose.yml logs -f webapp"
fi

# process magic link
if [ -n "$MAGIC" ]; then
  success "Magic login link detected"
  echo -e "${GREEN}$MAGIC${NC}"
else
  warn "Magic login link not found after timeout. Check manually with:"
  echo "  docker compose -f webapp/docker-compose.yml logs -f webapp"
fi

success "Trigger.dev self-host setup complete"
echo -e "Webapp available at: ${BLUE}http://localhost:8030${NC}"
