# 🚀 Lab Day 05: Production-Ready Multi-Service Architecture with Docker Compose

## 📌 1. Lab này học cái gì?

Bài lab này hướng dẫn xây dựng hệ thống đa dịch vụ (Multi-service) bao gồm **App Backend (Python)**, **PostgreSQL Database** và **Redis Cache** từ đầu bằng `docker-compose.yml`.

Mục tiêu chính là tiếp cận và triển khai mô hình hạ tầng container theo tư duy **Production-ready**:

- Cô lập mạng nội bộ giữa các service.
- Quản lý dữ liệu bền vững (Data Persistence) tránh mất dữ liệu.
- Kiểm soát chính xác thứ tự khởi chạy và độ sẵn sàng của hạ tầng (Startup Dependency & Healthcheck).

---

## 🧠 2. Kiến thức chính

1. **Custom Bridge Network:** Tự định nghĩa mạng bridge riêng để các container giao tiếp nội bộ qua tên service (Internal DNS Resolution) thay vì dùng IP tĩnh.
2. **Named Volumes vs Bind Mounts:** Quản lý lưu trữ dữ liệu cho database/cache trên Host OS an toàn, hiệu năng cao và đúng phân quyền.
3. **Healthcheck & Startup Order:** Kết hợp `healthcheck` với `depends_on (condition: service_healthy)` để đảm bảo backend chỉ khởi chạy khi database/cache đã thực sự sẵn sàng nhận kết nối (chứ không chỉ ở trạng thái `running`).
4. **YAML Multiline Handling:** Phân biệt và sử dụng đúng Literal Scalar (`|`) trong YAML để giữ nguyên định dạng dòng cho script.

---

## 🛠️ 3. Hướng dẫn vận hành (Chạy như thế nào?)

### Cấu trúc thư mục

```text
05/
├── docker-compose.yml
└── README.md
```
