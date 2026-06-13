# Production Branch Protection Example

Apply these settings in GitHub repository settings (or with GitHub API):

- Protect `main` branch:
  - Require pull request before merging
  - Require approvals: 2
  - Dismiss stale approvals on new commits
  - Require conversation resolution
  - Require status checks:
    - Deploy Environment / deploy (prod)
    - Promotion Guard / promotion-policy
  - Block force pushes
  - Block branch deletion

- Protect GitHub Environment `prod`:
  - Required reviewers: 2 people (platform/sre)
  - Wait timer if needed for change window
  - Environment secrets/vars scoped only to `prod`

These controls are intentionally separated from app repositories.
