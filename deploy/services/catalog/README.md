# Catalog Service GitOps Structure

Cấu trúc này triển khai catalog service sử dụng Kustomize base/overlay pattern và Flux CD cho image automation theo digest.

## Cấu trúc thư mục

```
deploy/
├── services/catalog/
│   ├── base/                          # Base manifests (shared)
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   └── ingress.yaml
│   └── overlays/                      # Environment-specific overlays
│       ├── test/
│       │   ├── kustomization.yaml
│       │   └── deployment-patch.yaml
│       ├── staging/
│       │   ├── kustomization.yaml
│       │   └── deployment-patch.yaml
│       └── prod/
│           ├── kustomization.yaml
│           └── deployment-patch.yaml
└── flux-system/
    ├── catalog-image-repository.yaml  # Image repository scanner
    ├── catalog-image-policy.yaml      # Image selection policies
    ├── catalog-image-automation.yaml  # Image update automation
    └── kustomization.yaml             # Flux system kustomization
```

## Cách sử dụng

### 1. Build manifest cho từng environment

```bash
# Test environment
kustomize build deploy/services/catalog/overlays/test

# Staging environment
kustomize build deploy/services/catalog/overlays/staging

# Prod environment
kustomize build deploy/services/catalog/overlays/prod
```

### 2. Deploy với Kustomize

```bash
# Test
kubectl apply -k deploy/services/catalog/overlays/test

# Staging
kubectl apply -k deploy/services/catalog/overlays/staging

# Prod
kubectl apply -k deploy/services/catalog/overlays/prod
```

### 3. Flux automation flow

Flux sẽ tự động:
1. Scan image repository (ghcr.io/aws/aws-retail-store-sample-app/catalog)
2. Filter tags theo pattern (test-*, staging-*, prod)
3. Detect new images theo policy
4. Update kustomization.yaml files với digest mới
5. Commit changes về Git repository
6. Deploy tới cluster

### Environment-specific configuration

#### Test (overlays/test)
- Replicas: 1
- Resources: cpu 50m, memory 64Mi
- Log level: debug
- Cache: disabled
- Image tag: test-latest
- Sync interval: 15m

#### Staging (overlays/staging)
- Replicas: 2
- Resources: cpu 200m, memory 256Mi
- Log level: info
- Cache: enabled
- Pod anti-affinity: preferred
- Image tag: staging-latest
- Sync interval: 15m

#### Prod (overlays/prod)
- Replicas: 3
- Resources: cpu 500m, memory 512Mi
- Log level: warn
- Cache: enabled
- Pod anti-affinity: required
- Image tag: prod
- Sync interval: 1h
- Digest policy: Always (strict)

## Flux Image Policies

### Catalog Test Policy
- Pattern: `^test-.*$`
- Strategy: alphabetical (desc) - lấy version mới nhất
- Reflection: Once - update khi có image mới

### Catalog Staging Policy
- Pattern: `^staging-.*$`
- Strategy: alphabetical (desc)
- Reflection: Once

### Catalog Prod Policy
- Pattern: `^prod$` (chỉ tag "prod")
- Strategy: alphabetical
- Reflection: Always - luôn update với latest prod digest

## Integration Points

1. **Image Registry**: ghcr.io/aws/aws-retail-store-sample-app/catalog
2. **Git Repository**: aws-retail-store-sample-app (Flux source)
3. **Namespaces**: test, staging, prod
4. **Image Update**: Tự động commit vào repo khi có image mới

## Customization

### Thay đổi image registry
Sửa các file:
- `base/kustomization.yaml` - images section
- `catalog-image-repository.yaml` - spec.image

### Thay đổi resource limits
Sửa các file overlay deployment-patch.yaml

### Thay đổi replicas
Sửa `overlays/*/kustomization.yaml` - replicas section

### Thay đổi Flux sync interval
Sửa `catalog-image-automation.yaml` - spec.interval
