#!/bin/bash

# Lấy đường dẫn tuyệt đối của thư mục chứa repo hiện tại
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Lấy chính xác user và group của người dùng (kể cả khi thực thi bằng sudo)
REAL_USER=${SUDO_USER:-$(whoami)}
REAL_GROUP=$(id -gn "$REAL_USER")

echo "Installing service for User '${REAL_USER}' (${REAL_GROUP}) at: ${CURRENT_DIR}"

# Thay thế toàn bộ 3 placeholders {{REPOS_DIR}}, {{USER}}, {{GROUP}} vào file service hệ thống
sed -e "s|{{REPOS_DIR}}|${CURRENT_DIR}|g" \
    -e "s|{{USER}}|${REAL_USER}|g" \
    -e "s|{{GROUP}}|${REAL_GROUP}|g" \
    app.service.template | sudo tee /etc/systemd/system/app.service > /dev/null

# Reload & Enable & Start Service
sudo systemctl daemon-reload
sudo systemctl enable --now app.service

echo "Done! Service is running."