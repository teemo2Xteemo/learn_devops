# 🧪 DevOps Lab 06: Quản lý Application Daemon & Log với Custom Systemd Service

---

## 🎯 1. Lab này học cái gì?

Bài lab này hướng dẫn bạn cách đóng gói và quản lý vòng đời của một ứng dụng chạy ngầm (Background Daemon/Service) trên hệ điều hành Linux bằng **Systemd**.

Đặc biệt, bài lab giải quyết bài toán thực chiến trong DevOps: **Làm sao để đóng gói file cấu hình `.service` trong Git Repository để có thể cài đặt tự động trên bất kỳ đường dẫn máy tính nào (Dynamic Repository Path)?**

---

## 🧠 2. Kiến thức chính là gì?

- **Cấu trúc & Vòng đời Systemd Unit File:** Đọc hiểu và làm chủ các khối `[Unit]`, `[Service]`, `[Install]`.
- **Cơ chế Auto-Restart & Resilience:** Cấu hình `Restart=on-failure` và `RestartSec` để Systemd tự động khôi phục ứng dụng ngay khi gặp sự cố crash.
- **Bảo mật Service (Hardening):** Giới hạn quyền hạn dịch vụ với `User=nobody`, `ProtectSystem=full`, `ProtectHome=true`, `NoNewPrivileges=true`.
- **Dynamic Path Resolution:** Kỹ thuật sử dụng File Template (`.template`) kết hợp với Bash Script (`sed`) để tự động truyền đường dẫn tuyệt đối `$PWD` vào cấu hình Systemd.
- **Tập trung Log với Journalctl:** Kỹ thuật theo dõi, truy vết và lọc log hệ thống theo mức độ nghiêm trọng (Log Level).

---

## 🚀 3. Chạy như thế nào?

### Bước 1: Cấp quyền thực thi cho các script

```bash
chmod +x app.sh install.sh uninstall.sh
```

### Bước 2: Cài đặt & Kích hoạt Dịch vụ

Chạy script `install.sh` để tự động tạo file service với đường dẫn động và kích hoạt dịch vụ:

```bash
./install.sh
```

### Bước 3: Kiểm tra Dịch vụ & Xem Log

- Kiểm tra trạng thái hoạt động:

```bash
sudo systemctl status app.service
```

- Theo dõi log realtime:

```bash
sudo journalctl -u app.service -f
```

### Bước 4: Gỡ bỏ Dịch vụ (Sau khi hoàn thành lab)

```bash
./uninstall.sh
```

## 🎯 4. Kết quả mong đợi là gì?

1. **Service khởi chạy thành công**: `app.service` đạt trạng thái `active (running)`.

2. **Khả năng tự phục hồi (Self-healing)**: Mẫu ứng dụng `app.sh` được cố tình lập trình để crash sau 10 nhịp heartbeat. Bạn sẽ quan sát thấy Systemd phát hiện trạng thái crash và tự động khởi động lại dịch vụ sau 5 giây.

3. **Log tập trung**: Lệnh `journalctl -u app.service -f` hiển thị rõ ràng từng dòng log heartbeat, thông báo lỗi `[CRITICAL]` khi crash và tiến trình restart từ Systemd.

## 🎓 5. Mình học được gì sau khi hoàn thành?

**Tư duy Production-ready**: Loại bỏ thói quen chạy ứng dụng thủ công bằng `nohup` hay `screen`; làm chủ cách quản lý dịch vụ chuẩn doanh nghiệp trên Linux.

**Tự động hóa Cài đặt**: Thành thạo cách viết bộ script `install.sh` / `uninstall.sh` tự động cho dự án.

**Kỹ năng Troubleshooting**: Thành thạo công cụ `journalctl` để tra cứu lỗi nhanh chóng thay vì tìm kiếm file log thô truyền thống.

**Nền tảng cho Container & K8s**: Hiểu rõ bản chất về Vòng đời tiến trình (Process Lifecycle), Restart Policy và Health Check - đây là tiền đề trực tiếp để học Kubernetes ở các Stage sau.
