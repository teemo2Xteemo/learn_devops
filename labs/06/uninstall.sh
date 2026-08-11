#!/bin/bash

# Tên dịch vụ systemd cần gỡ bỏ
SERVICE_NAME="app.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"

echo "=== Bắt đầu gỡ bỏ dịch vụ ${SERVICE_NAME} ==="

# 1. Dừng dịch vụ nếu đang chạy
if systemctl is-active --quiet "${SERVICE_NAME}"; then
    echo "[1/4] Đang dừng dịch vụ ${SERVICE_NAME}..."
    sudo systemctl stop "${SERVICE_NAME}"
else
    echo "[1/4] Dịch vụ không trong trạng thái chạy."
fi

# 2. Vô hiệu hóa tự động khởi động cùng hệ thống (Disable)
if systemctl is-enabled --quiet "${SERVICE_NAME}" 2>/dev/null; then
    echo "[2/4] Đang vô hiệu hóa auto-start cho ${SERVICE_NAME}..."
    sudo systemctl disable "${SERVICE_NAME}"
else
    echo "[2/4] Dịch vụ chưa được enable auto-start."
fi

# 3. Xóa file unit service trong /etc/systemd/system/
if [ -f "${SERVICE_PATH}" ] || [ -L "${SERVICE_PATH}" ]; then
    echo "[3/4] Đang xóa file ${SERVICE_PATH}..."
    sudo rm -f "${SERVICE_PATH}"
else
    echo "[3/4] Không tìm thấy file ${SERVICE_PATH}."
fi

# 4. Reload lại Systemd daemon và xóa trạng thái failed (nếu có)
echo "[4/4] Đang reload Systemd daemon & dọn dẹp trạng thái..."
sudo systemctl daemon-reload
sudo systemctl reset-failed

echo "=== Đã gỡ bỏ thành công ${SERVICE_NAME} khỏi hệ thống! ==="