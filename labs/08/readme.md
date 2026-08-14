# Mini-Lab Ngày 08: Bash Automation Scripting (Health-Check, Alerting & Log Rotation)

## 1. Lab này học cái gì?

Lab này hướng dẫn bạn xây dựng một **Bash Script tự động hóa chuẩn Production** phục vụ công tác vận hành hệ thống:

* Giám sát tài nguyên máy chủ (Disk Usage).
* Kiểm tra tính sẵn sàng (Health-check HTTP Status) của dịch vụ Web/Nginx được cấu hình từ Ngày 3.
* Tự động gửi cảnh báo (Alert) dạng JSON qua Webhook (Slack, Discord hoặc Mock endpoint).
* Quản lý vòng đời file log (Log Rotation & Retention) để tránh tràn ổ cứng.
* Thiết lập lập lịch định kỳ tự động với Cron job.

---

## 2. Kiến thức cốt lõi (Core Concepts)

* **Defensive Bash Scripting:** Sử dụng cờ `set -euo pipefail` để bắt lỗi nghiêm ngặt và ngăn script chạy sai luồng.
* **Concurrency & Lock Control:** Sử dụng `flock` và `trap` để đảm bảo tại một thời điểm chỉ có duy nhất một tiến trình script được thực thi, chống race-condition.
* **System Metrics Gathering:** Lấy và xử lý dữ liệu hệ thống từ các công cụ native (`df`, `awk`, `tr`).
* **Service Probing:** Kiểm tra trạng thái HTTP endpoint bằng `curl` với cờ timeout và status code extraction (`-w "%{http_code}"`).
* **Log Lifecycle Management:** Sử dụng `find` kết hợp điều kiện dung lượng (`-size`), thời gian sửa đổi (`-mtime`) và nén `gzip` để tối ưu dung lượng lưu trữ.
* **Automation Scheduling:** Cấu hình lập lịch với `crontab`.

---

## 3. Hướng dẫn cài đặt & Thực thi (How to Run)

### Bước 1: Tạo cấu trúc thư mục

```bash
sudo mkdir -p /opt/devops-monitor/{scripts,logs}
cd /opt/devops-monitor
```

### Bước 2: Tạo script thực thi

Tạo file `/opt/devops-monitor/scripts/monitor_and_rotate.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# --- CONFIGURATION ---
LOG_DIR="/opt/devops-monitor/logs"
LOG_FILE="${LOG_DIR}/system_monitor.log"
LOCK_FILE="/var/run/devops_monitor.lock"
DISK_THRESHOLD=85
WEBHOOK_URL="${ALERT_WEBHOOK_URL:-[https://httpbin.org/post](https://httpbin.org/post)}"
ENDPOINT_TO_CHECK="https://localhost/healthz"

# --- TRAP & CLEANUP ---
exec 200>"$LOCK_FILE"
flock -n 200 || { echo "[$(date -Iseconds)] [WARN] Another instance is running. Exiting." >> "$LOG_FILE"; exit 0; }

cleanup() {
    local exit_code=$?
    flock -u 200 2>/dev/null || true
    rm -f "$LOCK_FILE"
    exit "$exit_code"
}
trap cleanup EXIT INT TERM

# --- HELPER FUNCTIONS ---
log() {
    local level="$1"
    shift
    echo "[$(date '+\%Y-\%m-\%d \%H:\%M:\%S')] [${level}] $*" \vert{} tee -a "$LOG_FILE"
}

send_alert() {
    local message="$1"
    log "ALERT" "$message"
    curl -s -X POST -H "Content-Type: application/json" \
        -d "{\"event\": \"DevOps Alert\", \"message\": \"$message\", \"hostname\": \"$(hostname)\"}" \
        "$WEBHOOK_URL" > /dev/null 2>&1 || log "ERROR" "Failed to send alert via webhook"
}

# --- 1. SYSTEM HEALTH CHECK ---
log "INFO" "Starting health check routine..."

# Check Disk Usage
CURRENT_DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$CURRENT_DISK_USAGE" -ge "$DISK_THRESHOLD" ]; then
    send_alert "CRITICAL: Root filesystem usage is at ${CURRENT_DISK_USAGE}%"
else
    log "INFO" "Disk usage normal: ${CURRENT_DISK_USAGE}%"
fi

# Check HTTP Service Health Check
HTTP_STATUS=$(curl -k -s -o /dev/null -w "\%{http_code}" --connect-timeout 5 "$ENDPOINT_TO_CHECK" || echo "000")
if [ "$HTTP_STATUS" != "200" ]; then
    send_alert "WARNING: Service check failed on ${ENDPOINT_TO_CHECK} (Status:${HTTP_STATUS})"
else
    log "INFO" "Service endpoint healthy (HTTP 200)"
fi

# --- 2. AUTOMATED LOG ROTATION & RETENTION ---
log "INFO" "Running log maintenance..."
find "$LOG_DIR" -maxdepth 1 -type f -name "*.log" -size +10M ! -name "*.gz" -exec gzip {} \;
DELETED_LOGS=$(find "$LOG_DIR" -type f -name "*.gz" -mtime +7 -delete -print | wc -l)
log "INFO" "Cleaned up ${DELETED_LOGS} old log files."
log "INFO" "Routine completed."
```

### Bước 3: Cấp quyền và chạy thử

```bash
# Cấp quyền thực thi
sudo chmod +x /opt/devops-monitor/scripts/monitor_and_rotate.sh

# (Tùy chọn) Export Webhook thật nếu có:
# export ALERT_WEBHOOK_URL="[https://discord.com/api/webhooks/](https://discord.com/api/webhooks/)..."

# Chạy test thủ công
sudo /opt/devops-monitor/scripts/monitor_and_rotate.sh
```

### Bước 4: Thiết lập Cron Job

Mở cấu hình cron (`crontab -e`) và thêm dòng sau để chạy định kỳ mỗi 15 phút:

```bash
*/15 * * * * /opt/devops-monitor/scripts/monitor_and_rotate.sh >> /opt/devops-monitor/logs/cron_execution.log 2>&1
```

---

## 4. Kết quả mong đợi (Expected Outcome)

* File `/opt/devops-monitor/logs/system_monitor.log` được tạo và ghi lại lịch sử kiểm tra có cấu trúc rõ ràng (`INFO`, `WARN`, `ALERT`).

* Khi chạy 2 tiến trình script đồng thời, file lock ngăn chặn chạy trùng lặp và ghi log cảnh báo an toàn.

* Khi hạ service Nginx hoặc giả lập Disk đầy, webhook nhận được thông báo HTTP POST với payload JSON hợp lệ.

* File log dung lượng lớn được tự động nén `.gz` và các file quá 7 ngày được dọn dẹp sạch sẽ.

---

## 5. Mình học được gì sau khi hoàn thành? (Key Takeaways)

1. **Tư duy viết script phòng vệ (Defensive Scripting)**: Biết cách bọc bắt lỗi, kiểm soát exit codes và quản lý cleanup tài nguyên bằng `trap` khi tiến trình bị ngắt đột ngột.

2. **Hiểu bản chất của các Monitoring Agent**: Nắm được cơ chế cơ bản bên dưới của các hệ thống giám sát (như Datadog Agent, Prometheus Node Exporter) khi chúng đọc thông số OS và probe service.

3. **Kỹ năng tự động hóa hạ tầng cơ bản**: Tự xây dựng được hệ thống cảnh báo và bảo trì định kỳ mà không phụ thuộc vào các công cụ bên thứ ba cồng kềnh.
