# 🐳 Bài Lab 02: Pod Architecture – Resource Limits & Health Check Probes (Liveness, Readiness, Startup)

Lộ trình: DevOps Engineer chuyên sâu Kubernetes & Cloud Infrastructure  
Mức độ: Cơ bản - Trung cấp (Intermediate)  
Thời gian thực hành: 15 – 30 phút

---

## 🎯 1. Lab này học cái gì?

Bài lab này hướng dẫn bạn cách thiết lập và quản lý tài nguyên (CPU, Memory) chuẩn Production cho Pods trong Kubernetes, đồng thời áp dụng 3 loại Health Check Probes (`livenessProbe`, `readinessProbe`, `startupProbe`) để xây dựng cơ chế tự phục hồi (Self-Healing) và điều hướng lưu lượng truy cập (traffic) an toàn.

---

## 🧠 2. Kiến thức chính là gì?

- **Quản lý Tài nguyên (Resource Management):**
  - `requests`: Tài nguyên tối thiểu K8s Scheduler yêu cầu để tìm Node phù hợp cấp phát cho Pod.
  - `limits`: Hạn mức tài nguyên tối đa Pod được phép tiêu thụ.
    - Vượt **Memory Limit**: Pod bị hệ điều hành tiêu diệt do hết bộ nhớ (`OOMKilled` / Exit Code 137).
    - Vượt **CPU Limit**: Pod bị tiết giảm hiệu năng (`CPU Throttling`) chứ không bị ngắt tiến trình.
- **Cơ chế Health Check Probes:**
  - `livenessProbe`: Kiểm tra tiến trình bên trong container còn sống hay không. Nếu thất bại N lần liên tiếp, Kubernetes sẽ ngắt và khởi động lại (restart) container.
  - `readinessProbe`: Kiểm tra container đã sẵn sàng phục vụ request chưa. Nếu thất bại, Kubernetes gỡ IP của Pod khỏi danh sách Endpoints của Service để ngắt lưu lượng truy cập.
  - `startupProbe`: Bảo vệ các ứng dụng khởi động chậm, vô hiệu hóa Liveness và Readiness Probes cho tới khi ứng dụng hoàn tất quá trình khởi động ban đầu.

---

## 🛠️ 3. Hướng dẫn làm các bước chi tiết

### Bước 1: Khởi tạo thư mục và Namespace làm việc

Tạo thư mục dự án `devops-lab02` và namespace riêng trên cụm Kubernetes:
```bash
mkdir -p devops-lab02 && cd devops-lab02

kubectl create namespace devops-lab02

kubectl config set-context --current --namespace=devops-lab02
```
### Bước 2: Viết Manifest YAML cho Pod có Resource Limits & Probes

Tạo file `pod-health-demo.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
name: web-app-demo
labels:
    app: web-app
spec:
containers:
- name: nginx-container
  image: nginx:1.25-alpine
  ports:
  - containerPort: 80
  # Cấu hình giới hạn tài nguyên
  resources:
  requests:
      memory: "64Mi"
      cpu: "100m"      # 100m = 0.1 CPU core
  limits:
      memory: "128Mi"
      cpu: "200m"
  # Cấu hình Readiness Probe
  readinessProbe:
  httpGet:
      path: /
      port: 80
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 2
  # Cấu hình Liveness Probe
  livenessProbe:
  httpGet:
      path: /
      port: 80
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 3
```
Triển khai Pod lên cluster:
```bash
kubectl apply -f pod-health-demo.yaml
```
---

## 🚀 4. Chạy như thế nào?

Sau khi triển khai, bạn thực hiện các lệnh kiểm tra và giả lập sự cố sau:

1. **Kiểm tra trạng thái khởi động bình thường:**
```bash
kubectl get pod web-app-demo -o wide -w
kubectl describe pod web-app-demo  
```
2. **Giả lập sự cố Probe Failure:** Xóa tệp `index.html` trong container Nginx để cố tình làm hỏng HTTP GET `/`:
```bash
kubectl exec web-app-demo -- rm /usr/share/nginx/html/index.html  
```
3. **Theo dõi phản ứng tự chữa lành (Self-Healing) của Kubernetes:**
```bash
kubectl get pod web-app-demo -w
```
---

## ✅ 5. Kết quả mong đợi là gì?

1. **Khởi chạy ban đầu:** Pod chuyển sang trạng thái `1/1 READY` sau khi `readinessProbe` thành công.
2. **Khi gặp sự cố:**
   - Trạng thái `READY` chuyển về `0/1` do `readinessProbe` thất bại (K8s ngắt luồng traffic tới Pod).
   - Lệnh `kubectl describe pod web-app-demo` xuất hiện sự kiện cảnh báo: `Warning Unhealthy Pod/web-app-demo Liveness probe failed: HTTP probe failed with statuscode: 404`
   - Cột `RESTARTS` tăng lên `1` do Liveness Probe thất bại 3 lần liên tiếp và K8s tự động khởi động lại container để khôi phục trạng thái ban đầu.

---

## 💡 6. Mình học được gì sau khi hoàn thành?

- **Tư duy SRE & Môi trường Production:** Nắm vững tầm quan trọng của việc khai báo `requests` và `limits` để tránh xung đột tài nguyên giữa các Pod trên cùng một Node.
- **Kỹ năng thiết lập Self-Healing:** Biết cách phân biệt và kết hợp `livenessProbe`, `readinessProbe`, `startupProbe` để ứng dụng tự động phục hồi khi gặp sự cố mà không cần can thiệp thủ công.
- **Kỹ năng Giám sát & Troubleshooting:** Thành thạo cách kiểm tra sự kiện (`kubectl describe pod`) và hiểu rõ vòng đời của Pod trong Kubernetes khi xảy ra lỗi.
