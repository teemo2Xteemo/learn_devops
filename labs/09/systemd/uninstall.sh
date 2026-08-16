#!/bin/bash

for unit in backup-postgres.service backup-postgres.timer healthcheck.service healthcheck.timer log-rotate.service log-rotate.timer; do
    SERVICE_PATH="/etc/systemd/system/${unit}"

    if systemctl is-active --quiet "${unit}" 2>/dev/null; then
        echo "Stopping ${unit}..."
        sudo systemctl stop "${unit}"
    fi

    if systemctl is-enabled --quiet "${unit}" 2>/dev/null; then
        echo "Disabling ${unit}..."
        sudo systemctl disable "${unit}"
    fi

    if [ -f "${SERVICE_PATH}" ] || [ -L "${SERVICE_PATH}" ]; then
        echo "Removing ${SERVICE_PATH}..."
        sudo rm -f "${SERVICE_PATH}"
    fi
done

if [ -f "/usr/local/bin/log-rotate.sh" ]; then
    sudo rm -f "/usr/local/bin/log-rotate.sh"
fi

sudo systemctl daemon-reload
sudo systemctl reset-failed

echo "All lab 09 systemd units removed."
