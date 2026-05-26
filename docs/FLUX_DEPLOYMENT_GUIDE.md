**FluxCD + Kustomize — Hướng Dẫn Triển Khai**

**Tổng Quan**: Repo này dùng Kustomize (bases + overlays) để tổ chức Kubernetes manifests và FluxCD (GitRepository + Kustomization + Image Toolkit) để tự động sync và tự động cập nhật image.

**Prerequisites**:
- **Cluster & kubectl**: Truy cập tới cluster Kubernetes.
- **Flux CLI (tùy chọn)**: `flux` giúp bootstrap; có thể dùng `kubectl apply -k` thay thế.
- **Git token/SSH**: PAT hoặc SSH key có quyền đọc (và quyền ghi nếu ImageUpdateAutomation sẽ push).

**Tệp tham chiếu chính**:
- GitSource + Kustomizations: [deploy/flux-system/gotk-sync.yaml](../deploy/flux-system/gotk-sync.yaml)
- Image automation: [deploy/flux-system/catalog-image-automation.yaml](../deploy/flux-system/catalog-image-automation.yaml)
- Ví dụ overlay: [deploy/services/catalog/overlays/prod/kustomization.yaml](../deploy/services/catalog/overlays/prod/kustomization.yaml)

**1) Secrets cần chuẩn bị**
- `github-credentials` trong namespace `flux-system`: chứa PAT hoặc SSH private key (GitRepository trong `gotk-sync.yaml` tham chiếu tới secret này).
- Registry credentials (nếu image private): tạo `docker-registry` secret trong namespace ứng dụng (`prod`, `staging`, ...).

Ví dụ tạo secret PAT (HTTPS):
```bash
kubectl create namespace flux-system
kubectl -n flux-system create secret generic github-credentials \
  --from-literal=username=git \
  --from-literal=password=<PERSONAL_ACCESS_TOKEN>
```

Ví dụ secret registry (GHCR/private):
```bash
kubectl -n prod create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=<USERNAME> \
  --docker-password=<TOKEN> \
  --docker-email=you@example.com
```

**2) Cài Flux controllers**
- Cài CLI (tùy chọn) và controllers:
```bash
curl -s https://fluxcd.io/install.sh | sudo bash
flux install
```

**3) Triển khai manifests Flux trong repo**
- Option A — `flux bootstrap` (CLI sẽ tạo các resource và có thể push config):
```bash
flux bootstrap github \
  --owner=YOUR_ORG \
  --repository=aws-retail-store-sample-app \
  --branch=main \
  --path=deploy/flux-system \
  --personal
```
- Option B — Nếu controllers đã cài, apply trực tiếp manifests trong repo:
```bash
kubectl apply -k deploy/flux-system
```

**4) Định nghĩa Kustomization & flow**
- `gotk-sync.yaml` tạo `GitRepository` trỏ tới repo chính và Kustomization CRs cho từng overlay:
  - `catalog-test` → `./deploy/services/catalog/overlays/test`
  - `catalog-staging` → `./deploy/services/catalog/overlays/staging` (có `dependsOn: catalog-test`)
  - `catalog-prod` → `./deploy/services/catalog/overlays/prod` (có `dependsOn: catalog-staging`)
- `prune: true` và `wait: true` được bật để Flux tidy up và đảm bảo apply hoàn tất.

**5) Image automation**
- Các CR `ImageRepository`, `ImagePolicy` và `ImageUpdateAutomation` cấu hình detection và auto-bump tag/digest. Automation sẽ update files trong path (Setters/strategy) và push commit nếu token cho phép.
- Kiểm tra config: [deploy/flux-system/catalog-image-automation.yaml](../deploy/flux-system/catalog-image-automation.yaml)

**6) Kiểm tra & thao tác thường dùng**
- Kiểm tra sources git:
```bash
flux get sources git -n flux-system
```
- Kiểm tra kustomizations:
```bash
flux get kustomizations -n flux-system
```
- Reconcile thủ công:
```bash
flux reconcile source git aws-retail-store-sample-app -n flux-system
flux reconcile kustomization catalog-test -n flux-system
```

**7) Lưu ý vận hành**
- Token/SSH cần quyền phù hợp: read-only nếu chỉ sync, read+write nếu automation push commit.
- Tạo secrets trước khi apply `GitRepository` CR nếu CR tham chiếu secret.
- Thử chạy trên `test` trước khi bật automation cho `staging`/`prod`.

**8) Checklist ngắn trước khi bật auto-update**
- [ ] Token Git có quyền push nếu dùng ImageUpdateAutomation.
- [ ] Secrets registry đã có trong namespace ứng dụng.
- [ ] Format overlays tương thích với chiến lược update (Setters/patches).

---
File này được tạo tự động từ phân tích repo; nếu muốn, tôi có thể cập nhật `QUICK_START.md` hoặc thêm hướng dẫn tạo secrets tự động.
