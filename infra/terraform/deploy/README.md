# Kubernetes Layout

This repository now uses a Kustomize layout under `deploy/`:

- `deploy/base` contains shared Kubernetes resources.
- `deploy/clusters/test` contains the test overlay.
- `deploy/clusters/staging` contains the staging overlay.
- `deploy/clusters/prod` contains the production overlay.
- `deploy/flux-system` contains Flux image automation resources for the prod image stream.

See [docs/flux-role-and-workflow.md](docs/flux-role-and-workflow.md) for a short explanation of Flux's role in this project and how it relates to the current GitHub Actions deploy flow.

The prod overlay is annotated for Flux image updates so the rendered workload can be pinned by digest instead of only by tag.

Apply an environment with:

```bash
kubectl apply -k deploy/clusters/test
kubectl apply -k deploy/clusters/staging
kubectl apply -k deploy/clusters/prod
```

Each overlay owns the image reference, replica count, resource sizing, namespace, and environment-specific config for that cluster.