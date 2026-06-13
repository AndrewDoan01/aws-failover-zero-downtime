## Change Type

- [ ] Infra change (Terraform)
- [ ] Version promotion (test -> staging -> prod)
- [ ] Deploy workflow/policy update

## Deployment Traceability

- Release ID(s):
- App commit SHA(s):
- Related app repo PR/commit:

## Promotion Safety Checklist

- [ ] Artifact uses image digest, not mutable tag
- [ ] Digest is unchanged during promotion between environments
- [ ] Smoke test criteria are defined and valid
- [ ] No Terraform or cluster credentials exposed to app repo

## Risk and Rollback

- Risk level:
- Rollback plan (revert version commit):
