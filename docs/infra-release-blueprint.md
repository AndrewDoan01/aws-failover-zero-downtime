# Infra Release Blueprint

This repository is the source of truth for infrastructure and deployment versions by environment.
Application repositories produce container artifacts and release metadata, then open PRs here to trigger deployment.

## Environment Structure

- `deploy/versions/test.json`
- `deploy/versions/staging.json`
- `deploy/versions/prod.json`

Each file is validated against `deploy/schema/version-set.schema.json` and contains release metadata per service:

- immutable image digest (`image.digest`)
- release traceability (`release_id`, `app_commit_sha`)
- Helm chart reference (`chart`, `chart_version`)
- target namespace/release name (`namespace`, `release`)

## Deploy Workflow

Workflow: `.github/workflows/deploy-env.yml`

Trigger conditions:

- push to main when an environment version file changes
- manual dispatch with selected environment

Execution flow:

1. Validate version file schema
2. Check every digest exists in ECR
3. Render Helm manifests (saved under `.deploy_state/` in workflow runtime)
4. Deploy to target EKS namespace
5. Run smoke tests
6. Rollback automatically to previous Helm revision if smoke fails

## Promotion Workflow

Promotion path is commit-driven and PR-based:

- test -> staging -> prod

Rules:

- copy release blocks from lower environment to higher environment
- do not rebuild artifact in this repository
- digest must remain unchanged between environments

Workflow: `.github/workflows/promotion-guard.yml`

- validates digest invariants for staging/prod PRs
- blocks PR if digest drifts between adjacent environments

## Prod Protection Policy

Use GitHub repository settings with environments and branch protections.

Required controls:

- require 2 approvals for production changes
- block force push on deploy branches/main
- enforce required status checks (`deploy-env`, `promotion-guard`)
- require successful smoke test before deployment job completes
- optional change window using environment variables:
  - `PROD_CHANGE_WINDOW_START_UTC`
  - `PROD_CHANGE_WINDOW_END_UTC`

## IAM and Security Model

- Use one OIDC IAM role per environment (`test`, `staging`, `prod`)
- Set each role ARN in the matching GitHub Environment secret `AWS_ROLE_ARN`
- Scope role permissions to:
  - Terraform state backend access for this infra repo
  - EKS deploy operations for the matching environment only
- App repositories must not receive Terraform state or cluster deploy credentials
- Infra repository must not build/rebuild images

## End-to-End Flow

1. App repo builds image and outputs release manifest with immutable digest
2. App repo opens PR to update `deploy/versions/test.json`
3. Infra repo deploys test and runs smoke tests
4. Approved PR promotes identical digest to staging
5. Approved PR promotes identical digest to prod
6. On incident, rollback by reverting the environment version commit
