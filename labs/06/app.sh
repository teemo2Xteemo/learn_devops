#!/bin/bash

echo "Starting Dummy App Daemon..."

counter=0

while true; do
  counter=$((counter+1))
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] App is running smoothly. Heartbeat #$counter"
  
  # Cố tình gây crash khi counter đạt 10 để test auto-restart
  if [ $counter -eq 10 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CRITICAL] Fatal error encountered! Crashing application..." >&2
    exit 1
  fi
  sleep 2
done