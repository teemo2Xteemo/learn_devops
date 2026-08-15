#!/bin/bash

for unit in backup-postgres.service backup-postgres.timer healthcheck.service healthcheck.timer; do
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

sudo systemctl daemon-reload
sudo systemctl reset-failed

echo "All lab 09 systemd units removed."
