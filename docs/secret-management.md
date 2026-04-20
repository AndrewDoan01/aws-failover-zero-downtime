# Secret Management Guide

This project must not store plaintext secrets in repository files.

## 1) Where to store secrets

- Terraform Cloud workspace variables (sensitive): runtime for Terraform plans/applies.
- GitHub Environment secrets: deployment runtime secrets for Actions.
- AWS IAM Identity Center or short-lived credentials: local developer auth.

## 2) Local Terraform usage (safe)

Do not write secrets in terraform.tfvars.

PowerShell example:

```powershell
$env:TF_VAR_db_password = "<strong-password>"
$env:AWS_PROFILE = "your-profile"
terraform -chdir=infra/terraform plan
```

Optional temporary credentials:

```powershell
$env:AWS_ACCESS_KEY_ID = "<temporary-access-key-id>"
$env:AWS_SECRET_ACCESS_KEY = "<temporary-secret-access-key>"
$env:AWS_SESSION_TOKEN = "<temporary-session-token>"
```

## 3) GitHub Actions usage (safe)

- Use OIDC role assumption only.
- Keep role ARN in GitHub Environment secret AWS_ROLE_ARN.
- Keep non-secret settings in GitHub Environment Variables.

## 4) Incident response if a secret is exposed

1. Revoke or rotate the exposed credential immediately.
2. Invalidate dependent sessions or tokens.
3. Audit CloudTrail and relevant service logs.
4. Remove secret from git history if it was committed.
5. Reissue least-privilege credentials.

## 5) Preventive controls enabled in this repo

- tfvars files are gitignored.
- Provider credentials are no longer hardcoded in Terraform providers.
- CI secret scanning workflow: .github/workflows/secret-scan.yml
