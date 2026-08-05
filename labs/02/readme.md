# Lab: Cấu Hình Custom Networking Trên Amazon EKS Với AWS VPC CNI

## 1. Lab này học cái gì?
Bài lab này hướng dẫn thực hành cấu hình tính năng **Custom Networking** trên cụm **Amazon EKS** bằng **AWS VPC CNI Plugin**. 

Thông qua bài lab, bạn sẽ học cách tách biệt dải IP của các Pods sang một **Secondary Subnet/CIDR** hoàn toàn độc lập với Subnet của Worker Node, giúp giải quyết bài toán cạn kiệt IP VPC trong môi trường thực tế (Enterprise EKS).

---

## 2. Kiến thức chính là gì?
* **AWS VPC CNI (Container Network Interface):** Cơ chế gán trực tiếp địa chỉ IP từ AWS VPC ENI cho từng Pod trong Kubernetes.
* **CRD `ENIConfig`:** Tài nguyên mở rộng của Kubernetes do AWS định nghĩa để gán Subnet ID và Security Group riêng cho Pods dựa trên Availability Zone (AZ).
* **DaemonSet Environment Variables:** Cấu hình các biến môi trường `AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG` và `ENI_CONFIG_LABEL_DEF` trên `aws-node`.
* **Kustomize & Declarative Deployment:** Quản lý và đóng gói các tệp cấu hình Kubernetes bằng Kustomize.

---

## 3. Chạy như thế nào?

### Yêu cầu tiền đề (Prerequisites)
1. Cụm **Amazon EKS** đã hoạt động và có ít nhất 1 Worker Node.
2. Công cụ CLI trên máy local: `aws-cli`, `kubectl`, `kustomize`.
3. Đã có **Secondary Subnet ID** và **Security Group ID** riêng cho Pod trên AWS VPC.

### Các lệnh thực thi chính
```bash
# 1. Áp dụng cấu hình ENIConfig
kubectl apply -k .

# 2. Bật Custom Networking trên aws-node DaemonSet
kubectl set env daemonset aws-node -n kube-system AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG=true
kubectl set env daemonset aws-node -n kube-system ENI_CONFIG_LABEL_DEF=topology.kubernetes.io/zone

# 3. Gán Annotation cho Worker Node (nếu chưa gán tự động)
kubectl annotate node <tên-node> [k8s.amazonaws.com/eniConfig=](https://k8s.amazonaws.com/eniConfig=)<tên-az> --overwrite

# 4. Khởi động lại CNI và Deployment ứng dụng
kubectl rollout restart daemonset aws-node -n kube-system
kubectl rollout restart deployment sample-app