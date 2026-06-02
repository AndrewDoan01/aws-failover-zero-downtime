# PoC Catalog GitOps Implementation Guide

## Tổng quan

Cấu trúc này cung cấp một giải pháp hoàn chỉnh để:
- Quản lý catalog service với Kustomize base/overlay pattern
- Tự động cập nhật image theo digest bằng Flux CD
- Deploy tới 3 môi trường (test, staging, prod) với cấu hình riêng
- Đảm bảo promotion flow: test → staging → prod

## Cấu trúc file đã tạo

### Base Manifests (`deploy/services/catalog/base/`)
- **deployment.yaml** - Deployment manifest với health checks, resources
- **service.yaml** - Service ClusterIP để expose catalog internally
- **configmap.yaml** - Cấu hình mặc định (log level, cache, db settings)
- **ingress.yaml** - ALB Ingress để expose /catalog path
- **kustomization.yaml** - Kustomize base definition

### Environment Overlays

#### `deploy/services/catalog/overlays/test/`
- kustomization.yaml - Replicas: 1, Namespace: test
- deployment-patch.yaml - CPU: 50m, Memory: 64Mi, Log: debug, Cache: off

#### `deploy/services/catalog/overlays/staging/`
- kustomization.yaml - Replicas: 2, Namespace: staging
- deployment-patch.yaml - CPU: 200m, Memory: 256Mi, Pod anti-affinity: preferred

#### `deploy/services/catalog/overlays/prod/`
- kustomization.yaml - Replicas: 3, Namespace: prod
- deployment-patch.yaml - CPU: 500m, Memory: 512Mi, Pod anti-affinity: required

### Flux Automation (`deploy/flux-system/`)

#### Image Repository & Policies
- **catalog-image-repository.yaml**
  - Quét ghcr.io/aws/aws-retail-store-sample-app/catalog
  - Interval: 5m

- **catalog-image-policy.yaml**
  - test policy: Pattern `^test-.*$` (latest dev build)
  - staging policy: Pattern `^staging-.*$`
  - prod policy: Pattern `^prod$` (strict, production tag)

#### Image Automation
- **catalog-image-automation.yaml**
  - Test automation: Interval 15m, Setters strategy
  - Staging automation: Interval 15m, Setters strategy
  - Prod automation: Interval 1h, Always digest reflection

#### Flux Sync
- **gotk-sync.yaml**
  - GitRepository source: aws-retail-store-sample-app
  - Kustomization resources cho test, staging, prod
  - Dependency chain: test → staging → prod

#### System Kustomization
- **kustomization.yaml** - Include tất cả Flux resources

## Workflow Promotion

```
  [Push image: test-v1.2.3]
         ↓
  [Flux detects test image]
         ↓
  [Update overlays/test/kustomization.yaml → commit to Git]
         ↓
  [Flux syncs test environment]
         ↓
  [Manual or automated tag: test-v1.2.3 → staging-v1.2.3]
         ↓
  [Flux detects staging image]
         ↓
  [Update overlays/staging/kustomization.yaml → commit to Git]
         ↓
  [Flux syncs staging environment]
         ↓
  [Manual tag: v1.2.3 → prod (or use prod tag)]
         ↓
  [Flux detects prod image]
         ↓
  [Update overlays/prod/kustomization.yaml with digest]
         ↓
  [Flux syncs prod environment]
```

## Cách sử dụng

### 1. Kiểm tra Kustomize build output

```bash
# Test environment
cd e:\NT114\aws-failover-zero-downtime
kustomize build deploy/services/catalog/overlays/test

# Staging environment
kustomize build deploy/services/catalog/overlays/staging

# Prod environment
kustomize build deploy/services/catalog/overlays/prod
```

### 2. Deploy thủ công (nếu không dùng Flux)

```bash
# Apply test
kubectl apply -k deploy/services/catalog/overlays/test

# Apply staging
kubectl apply -k deploy/services/catalog/overlays/staging

# Apply prod
kubectl apply -k deploy/services/catalog/overlays/prod
```

### 3. Flux bootstrap (nếu cần)

```bash
# Bootstrap Flux (if not already done)
flux bootstrap github \
  --owner=<github-org> \
  --repo=aws-retail-store-sample-app \
  --personal=true \
  --private=true \
  --path=deploy/flux-system
```

### 4. Verify Flux sync

```bash
# Check Flux resources
kubectl get kustomization -n flux-system
kubectl get imagerepository -n flux-system
kubectl get imagepolicy -n flux-system
kubectl get imageupdateautomation -n flux-system

# Monitor logs
flux logs -f --name=catalog-test
flux logs -f --name=catalog-staging
flux logs -f --name=catalog-prod
```

## Image Tag Convention

- **Test**: `test-<version>` hoặc `test-<date>` (e.g., test-v1.2.3, test-20260526)
- **Staging**: `staging-<version>` (e.g., staging-v1.2.3)
- **Prod**: `prod` (một tag cố định, Flux cập nhật digest)

## Customization points

### Thay đổi image registry
1. Sửa `base/kustomization.yaml` - images[0].newName
2. Sửa `catalog-image-repository.yaml` - spec.image

### Thay đổi resource limits
Sửa `overlays/{env}/deployment-patch.yaml` - spec.template.spec.containers[0].resources

### Thay đổi replicas
Sửa `overlays/{env}/kustomization.yaml` - replicas section

### Thay đổi Flux sync frequency
Sửa `gotk-sync.yaml` - spec.interval hoặc `catalog-image-automation.yaml` - spec.interval

### Thay đổi image tag pattern
Sửa `catalog-image-policy.yaml` - spec.filterTags.pattern

## Kết hợp với existing app

Cấu trúc này hoàn toàn độc lập với existing app manifests ở `deploy/base/` và `deploy/clusters/`. 
Hai flow có thể chạy song song:
- Existing app flow: `deploy/base/` → `deploy/clusters/{env}/`
- Catalog flow: `deploy/services/catalog/overlays/{env}/` ← Flux sync từ gotk-sync.yaml

Nếu muốn hợp nhất, có thể:
1. Tạo top-level kustomization để compose cả hai
2. Hoặc move catalog vào existing deploy/clusters structure

## Kiểm tra

```bash
# Verify manifests render correctly
kubectl kustomize deploy/services/catalog/base
kubectl kustomize deploy/services/catalog/overlays/test
kubectl kustomize deploy/services/catalog/overlays/staging
kubectl kustomize deploy/services/catalog/overlays/prod

# Verify Flux resources
kubectl get all -n flux-system | grep catalog
```

## Next Steps

1. ✅ Cấu trúc PoC catalog tạo xong
2. ⏳ Update CI/CD để push images với tags (test-*, staging-*, prod)
3. ⏳ Bootstrap Flux trên các cluster
4. ⏳ Test image automation flow trên test environment
5. ⏳ Validate promotion flow test → staging → prod
