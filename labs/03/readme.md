# Lab 01: Thiết Kế & Cấp Phát Hạ Tầng Mạng VPC Chuẩn Doanh Nghiệp Cho Amazon EKS Bằng Terraform

## 1. Lab này học cái gì?
Bài lab này hướng dẫn tự động hóa thiết kế và cấp phát hạ tầng mạng **VPC (Virtual Private Cloud)** phân tầng chuẩn doanh nghiệp trên Amazon Web Services (AWS) sử dụng công cụ **Terraform (Infrastructure as Code - IaC)**. 

Mục tiêu chính là xây dựng một môi trường mạng cô lập, an toàn và tối ưu hóa chi phí để chuẩn bị sẵn sàng cho việc triển khai cụm **Amazon EKS (Elastic Kubernetes Service)** ở các bài học tiếp theo.

---

## 2. Kiến thức chính là gì?
* **Kiến trúc VPC phân tầng (Tiered VPC Architecture):** Hiểu rõ sự khác biệt giữa Public Subnet (chứa Ingress/Load Balancer) và Private Subnet (chứa K8s Worker Nodes & Databases).
* **Cơ chế giao tiếp Internet (IGW vs NAT Gateway):** 
  * **Internet Gateway (IGW):** Định tuyến lưu lượng 2 chiều (Inbound & Outbound) cho Public Subnet.
  * **NAT Gateway (NGW):** Thực hiện Source NAT (SNAT), cho phép Private Subnet gửi dữ liệu ra ngoài Internet (Outbound-only) mà không bị phơi bày địa chỉ IP nội bộ.
* **Bảng định tuyến (Route Table & Association):** Cách tạo và liên kết các quy tắc định tuyến vào từng Subnet tương ứng.
* **Kubernetes Auto-Discovery Tags:** Ý nghĩa các nhãn (tags) đặc biệt như `kubernetes.io/role/elb` và `kubernetes.io/role/internal-elb` giúp AWS Load Balancer Controller tự động phát hiện Subnets để tạo Load Balancer.
* **Tư duy bảo mật nhiều lớp (Defense in Depth):** Bảo vệ cụm K8s bằng cách giấu hoàn toàn Worker Nodes khỏi Internet.

---

## 3. Chạy như thế nào?

### Yêu cầu tiên quyết (Prerequisites)
* Đã cài đặt **AWS CLI** và cấu hình tài khoản AWS (`aws configure`).
* Đã cài đặt **Terraform** phiên bản `>= 1.7.0`.

### Lệnh thực thi nhanh (Quick Commands)
```bash
# 1. Khởi tạo dự án và tải Provider
terraform init

# 2. Kiểm tra kế hoạch thay đổi hạ tầng
terraform plan

# 3. Tiến hành cấp phát tài nguyên trên AWS
terraform apply -auto-approve

# 4. (Sau khi học xong) Dọn dẹp tài nguyên để tránh mất chi phí
terraform destroy -auto-approve