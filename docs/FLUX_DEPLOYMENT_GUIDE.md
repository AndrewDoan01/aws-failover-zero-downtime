**FluxCD + Kustomize — Hướng Dẫn Triển Khai (Chi Tiết)**

Mục tiêu của tài liệu: hướng dẫn từng bước để chuẩn bị hạ tầng với Terraform, cấu hình secrets, cài FluxCD, bootstrap repo Kustomize, bật Image Automation và thao tác vận hành cơ bản.

1) Tổng quan workflow
- Terraform tạo hạ tầng (EKS, VPC, IAM, S3 backend, ...)
- Sau khi có cluster, dùng `kubectl` để xác thực và cài Flux controllers.
- Flux `GitRepository` CR trỏ tới repo; `Kustomization` CR trỏ tới từng overlay (test/staging/prod).
- Image Toolkit (ImageRepository/ImagePolicy/ImageUpdateAutomation) detect image updates và (nếu có quyền) commit thay đổi vào repo; Flux apply thay đổi đó.

2) Chuẩn bị môi trường & quyền
- Tools local: `terraform`, `aws` CLI, `kubectl`, `flux` (CLI optional). Kiểm tra:
```bash
terraform version
aws --version
kubectl version --client
flux --version
```
- AWS credentials: đặt `AWS_PROFILE` hoặc `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_REGION`.
- GitHub: tạo Personal Access Token (PAT) hoặc SSH key; token cần `repo` scope nếu repo private and/or automation sẽ push.

3) Kiểm tra Terraform trong repo
- Thư mục: `aws-failover-zero-downtime/infra/terraform` (files: `backend.tf`, `main.tf`, `variables.tf`, `outputs.tf`). Mở `backend.tf` để xác định S3 bucket/DynamoDB table nếu dùng remote state.
- Tìm biến bắt buộc trong `variables.tf`. Ví dụ thường có: `cluster_name`, `region`, `node_instance_type`, `vpc_id` hoặc `s3_backend_bucket`.

4) Chạy Terraform (an toàn)
- Chuẩn bị backend config (nếu backend yêu cầu):
```powershell
cd aws-failover-zero-downtime/infra/terraform
terraform init -backend-config="bucket=<S3_BUCKET>" -backend-config="region=<REGION>" -backend-config="key=path/to/terraform.tfstate"
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```
- Nếu dùng local state thì bỏ `-backend-config`.
- Sau `apply`, kiểm tra outputs với `terraform output -json` để lấy `cluster_name` hoặc endpoint.

5) Lấy kubeconfig cho cluster
- Ví dụ EKS:
```bash
aws eks update-kubeconfig --name <cluster-name> --region <region>
kubectl get nodes
```
- Đảm bảo `kubectl get nodes` trả về node(s).

6) Tạo secrets cần thiết (chi tiết)
- Namespace `flux-system`:
```bash
kubectl create namespace flux-system
```
- Git (HTTPS PAT) — secret đọc/ghi (nếu ImageUpdateAutomation push):
```bash
kubectl -n flux-system create secret generic github-credentials \
  --from-literal=username=git \
  --from-literal=password=<PERSONAL_ACCESS_TOKEN>
```
- Git (SSH key) — tạo từ private key file và known_hosts:
```bash
kubectl -n flux-system create secret generic github-ssh \
  --from-file=identity=./id_rsa \
  --from-file=known_hosts=./known_hosts
```
- Registry (private image) — docker-registry secret trong namespace ứng dụng:
```bash
kubectl -n prod create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=<USERNAME> \
  --docker-password=<TOKEN> \
  --docker-email=you@example.com
```
- Bảo mật: lưu PAT/keys trong vault nếu có; cân nhắc dùng sealed-secrets hoặc ExternalSecrets.

7) Cài Flux controllers
- Cách nhanh với CLI:
```bash
curl -s https://fluxcd.io/install.sh | sudo bash
flux install
```
- `flux install` sẽ tạo CRDs và controller trong namespace `flux-system`.

8) Bootstrap repo Flux (2 cách)
- Option A — `flux bootstrap github` (CLI tự tạo GitRepository CR, optionally push kustomize files):
```bash
flux bootstrap github \
  --owner=YOUR_ORG \
  --repository=aws-retail-store-sample-app \
  --branch=main \
  --path=deploy/flux-system \
  --personal
```
- Option B — Nếu đã chuẩn bị `deploy/flux-system` trong repo, apply trực tiếp:
```bash
kubectl apply -k deploy/flux-system
```
- Lưu ý: nếu `GitRepository` CR tham chiếu tới `github-credentials`, tạo secret trước khi apply.

9) Giải thích `gotk-sync.yaml` (Flux Kustomization mẫu)
- `GitRepository` (source.toolkit.fluxcd.io/v1beta2): trỏ tới URL repo, branch, interval, secretRef.
- `Kustomization` (kustomize.toolkit.fluxcd.io/v1):
  - `sourceRef`: liên kết tới `GitRepository` source.
  - `path`: đường dẫn tới overlay trong repo (`./deploy/services/catalog/overlays/test`).
  - `prune: true`: Flux sẽ xóa resources không còn trong manifests.
  - `wait: true`, `timeout`: chờ apply hoàn tất.
  - `dependsOn`: cho phép tạo chain promotion (test -> staging -> prod).

10) Image Toolkit (chi tiết)
- Các CRs liên quan:
  - `ImageRepository`: nơi Flux quét tags/digests.
  - `ImagePolicy`: filter tags/digest và policy selection.
  - `ImageUpdateAutomation`: rule để update files (Setters, Replace, etc.) và commit vào git.
- Chiến lược update: `strategy: Setters` dùng kustomize vars/setters (hoặc `Replace` cho text patch). Hãy bảo đảm overlays có chỗ để Flux update (ví dụ `kustomization.yaml` chứa `images` mục với `newTag` hoặc placeholder comment for $imagepolicy).
- Nếu automation sẽ push, token trong `github-credentials` phải có quyền push.

11) Kiểm tra & reconcile thủ công
- Xem Git sources:
```bash
flux get sources git -n flux-system
```
- Xem Kustomizations:
```bash
flux get kustomizations -n flux-system
```
- Reconcile thủ công:
```bash
flux reconcile source git aws-retail-store-sample-app -n flux-system
flux reconcile kustomization catalog-test -n flux-system
```
- Kiểm tra Image CRs bằng `kubectl`:
```bash
kubectl -n flux-system get imagerepositories,imagepolicies,imageupdateautomations
```

12) Troubleshooting phổ biến
- `Kustomization` stuck: kiểm tra `kubectl -n flux-system describe kustomization <name>` và sự kiện.
- Git auth error: kiểm tra secret tên đúng và nội dung token/SSH key.
- Image automation không update: kiểm tra `ImagePolicy` filterTags pattern và interval; kiểm tra quyền push.
- Logs: `kubectl -n flux-system logs deployment/kustomize-controller` và `source-controller`, `image-automation-controller`.

13) Promotion flow thực tế
- `catalog-test` apply overlay `test`.
- Khi `catalog-test` thành công, `catalog-staging` (dependsOn: `catalog-test`) sẽ reconcile và apply overlay `staging`.
- Tương tự cho `catalog-prod`.

14) Checklist trước khi bật auto-update
- Token Git có quyền push nếu ImageUpdateAutomation cần commit.
- Secrets đã được tạo trong `flux-system` trước khi apply `GitRepository` CR.
- Overlays có cấu trúc phù hợp cho chiến lược update (ví dụ `images` entries trong `kustomization.yaml`).

15) Tài liệu & lệnh tham khảo nhanh
- Bootstrap (CLI): `flux bootstrap github --owner=... --repository=... --path=deploy/flux-system`
- Reconcile: `flux reconcile kustomization <name> -n flux-system`
- Xem resources Flux: `flux get all -n flux-system`

---
Nếu bạn muốn, tôi có thể:
- Cập nhật `QUICK_START.md` với các lệnh rút gọn.
- Tạo script PowerShell để chạy `terraform init/plan/apply` an toàn với backend-config placeholders.
- Tạo sẵn `kubectl` commands để tạo mọi secret cần thiết cho repo này.

File này đã được mở rộng với hướng dẫn chi tiết; cho tôi biết nếu cần thêm đoạn ví dụ cụ thể cho `backend.tf` hoặc template `ImageUpdateAutomation`.
