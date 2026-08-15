#!/bin/bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${CURRENT_DIR}/.." && pwd)"
REAL_USER=${SUDO_USER:-$(whoami)}
REAL_GROUP=$(id -gn "$REAL_USER")

echo "Installing systemd units for User '${REAL_USER}' (${REAL_GROUP}) at: ${REPO_DIR}"

sed -e "s|{{REPOS_DIR}}|${REPO_DIR}|g" \
    -e "s|{{USER}}|${REAL_USER}|g" \
    -e "s|{{GROUP}}|${REAL_GROUP}|g" \
    "${CURRENT_DIR}/backup-postgres.service.template" | sudo tee /etc/systemd/system/backup-postgres.service > /dev/null

sed -e "s|{{REPOS_DIR}}|${REPO_DIR}|g" \
    -e "s|{{USER}}|${REAL_USER}|g" \
    -e "s|{{GROUP}}|${REAL_GROUP}|g" \
    "${CURRENT_DIR}/healthcheck.service.template" | sudo tee /etc/systemd/system/healthcheck.service > /dev/null

sudo cp "${CURRENT_DIR}/backup-postgres.timer" /etc/systemd/system/backup-postgres.timer
sudo cp "${CURRENT_DIR}/healthcheck.timer" /etc/systemd/system/healthcheck.timer

sudo systemctl daemon-reload
sudo systemctl enable --now backup-postgres.timer
sudo systemctl enable --now healthcheck.timer

echo "Done! Backup timer and healthcheck timer are active."
