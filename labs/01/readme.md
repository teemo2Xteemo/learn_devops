# 🐳 Bài Lab 01: Container Runtime & Tối Ưu Hóa Dockerfile Cho Microservices

> **Lộ trình**: DevOps Engineer chuyên sâu Kubernetes & Cloud Infrastructure  
> **Mức độ**: Cơ bản \- Trung cấp (Intermediate)  
> **Thời gian thực hành**: 15 – 30 phút

---

## 🎯 1. Lab này học cái gì?

Bài lab này hướng dẫn bạn cách chuyển đổi một ứng dụng Backend (Microservices) từ cách đóng gói thô sơ thành một **Container Image đạt chuẩn Production**. Bạn sẽ thực hành kỹ thuật **Multi-stage Build**, loại bỏ toàn bộ các công cụ biên dịch thừa (compiler, SDK) khỏi Runtime Image, và định hình tư duy đóng gói phần mềm an toàn, siêu nhẹ cho Kubernetes.

---

## 🧠 2. Kiến thức chính là gì?

- **Phân biệt Container Runtimes**:
  - **High-level Runtime** (`containerd`, `CRI-O`): Quản lý vòng đời container, kéo image, quản lý mạng và lưu trữ.
  - **Low-level Runtime** (`runc`): Tương tác trực tiếp với Kernel (namespaces, cgroups) để khởi tạo và chạy process container.
- **Kỹ thuật Multi-stage Build**: Phân tách quá trình **Build** (cần SDK, thư viện biên dịch) và quá trình **Runtime** (chỉ chứa file nhị phân đã biên dịch).
- **Tối ưu Base Image**: Sử dụng **Distroless Image** (`gcr.io/distroless/static-debian12`) hoặc **Alpine Linux** giúp giảm kích thước Image từ \>800MB xuống \<20MB, đồng thời giảm thiểu bề mặt tấn công (Attack Surface).
- **Security Context (Non-root User)**: Cấu hình ứng dụng chạy bằng user phi quản trị (`UID 65532 / nonroot`) để phòng chống lỗ hổng leo thang đặc quyền (Container Escape).
- **Quản lý Image Tag**: Hiểu lý do tại sao tuyệt đối không dùng `:latest` trên môi trường Production & GitOps.

---

## 🛠️ 3. Hướng dẫn làm các bước chi tiết

### Bước 1: Chuẩn bị thư mục và mã nguồn ứng dụng

Tạo thư mục dự án và file mã nguồn Go đơn giản `main.go`:

```bash
mkdir -p devops-lab01 && cd devops-lab01
```

Tạo file `main.go`:

```go
package main

import (
	"fmt"
	"net/http"
)

func main() {

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "🚀 DevOps Daily - Lab 01 Completed Successfully!")
	})

	fmt.Println("Server is running on port 8080...")

	if err := http.ListenAndServe(":8080", nil); err != nil {
		panic(err)
	}
}
```

### Bước 2: Viết Dockerfile tối ưu (Multi-stage Build)

Tạo file `Dockerfile` trong cùng thư mục:

```dockerfile
#==========================================
# STAGE 1: Build Phase
#==========================================

FROM golang:1.22-alpine AS builder

WORKDIR /app

# Copy mã nguồn và biên dịch ứng dụng tĩnh (CGO\_ENABLED=0)

COPY main.go .

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o server main.go

#==========================================
# STAGE 2: Production Runtime Phase
#==========================================

FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /

# Copy duy nhất file nhị phân đã build từ Stage 1

COPY --from=builder /app/server /server

EXPOSE 8080

# Chạy dưới quyền user nonroot (UID 65532\)

USER nonroot:nonroot

ENTRYPOINT ["/server"]
```

### Bước 3: Biên dịch và Thực thi Container

1. **Biên dịch Docker Image**:

```bash
docker build -t devops-lab01:v1.0 .
```

2. **Chạy Container**:

```bash
docker run -d -p 8080:8080 --name lab01-container devops-lab01:v1.0
```

---

## 🚀 4. Chạy như thế nào?

Sau khi khởi chạy container, bạn thực hiện kiểm tra hoạt động và các thông số bảo mật bằng các lệnh sau:

- **Kiểm tra phản hồi của ứng dụng (HTTP API)**:

```bash
curl http://localhost:8080
```

- **Kiểm tra kích thước Image đã tối ưu**:

```bash
docker images | grep devops-lab01
```

- **Xác minh User đang thực thi trong Container (Security Verification)**:

```bash
docker exec lab01-container id
```

---

## ✅ 5. Kết quả mong đợi là gì?

1. **Phản hồi API**: `curl` trả về chuỗi text: `🚀 DevOps Daily - Lab 01 Completed Successfully!`
2. **Kích thước Image siêu nhẹ**: Dung lượng Image `devops-lab01:v1.0` có kích thước **\< 20 MB** (so với \> 800 MB nếu dùng Golang base image thông thường).
3. **User phi-root**: Kết quả lệnh `id` hiển thị: `uid=65532(nonroot) gid=65532(nonroot) groups=65532(nonroot)` Xác nhận container đang chạy an toàn dưới quyền non-root.

---

## 💡 6. Mình học được gì sau khi hoàn thành?

- **Kỹ năng Đóng gói Cloud-Native**: Biết cách tạo ra Container Image chuẩn Production nhẹ, sạch, không chứa công cụ thừa.
- **Tư duy DevSecOps (Shift-Left Security)**: Thiết lập cấu hình an toàn ngay từ bước viết Dockerfile (Non-root, Distroless) giúp giảm rủi ro lỗ hổng bảo mật khi triển khai lên Kubernetes.
- **Tối ưu Chi phí & Tốc độ Deployment**: Image dung lượng nhỏ giúp giảm thời gian Pull/Push qua Registry (ECR/DockerHub), tiết kiệm băng thông và tăng tốc độ Auto-scaling Pods trên K8s.
- **Chuẩn bị cho GitOps/ArgoCD**: Hiểu tầm quan trọng của việc gán Version Tag rõ ràng (`v1.0`) thay vì dùng `:latest`.
