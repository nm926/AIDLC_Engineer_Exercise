name: GitHub CI/CD Pipeline Documentation

This directory contains the complete GitHub Actions CI/CD pipeline for the EKS Karpenter Observability Lab.

## Workflows Overview

### 1. test-validate.yml
**Trigger:** Pull requests and pushes to develop
**Purpose:** Validates code quality, runs tests, and verifies configurations

**Jobs:**
- `python-lint` - Format checking with Black, isort, pylint, flake8
- `python-test` - Unit tests with pytest and coverage
- `security-scan` - Bandit and safety for vulnerability detection
- `validate-config` - Configuration validation with Pydantic
- `docker-build` - Build Docker images for all services
- `k8s-validate` - Kubernetes manifest validation with kubeval
- `summary` - Test summary

**Required to merge:** ✅ All checks must pass

### 2. build-push.yml
**Trigger:** Merge to main branch
**Purpose:** Builds and pushes Docker images to AWS ECR

**Jobs:**
- `build-fraud-detection` - Builds and scans fraud detection service
- `build-frontend` - Builds and scans frontend service
- `create-release` - Creates GitHub release with build info
- `notify` - Notifies of successful build

**Outputs:**
- Docker images pushed to ECR
- GitHub release created with image URIs
- Image scan initiated

### 3. deploy.yml
**Trigger:** Manual workflow_dispatch
**Purpose:** Deploys applications to staging or production

**Jobs:**
- `validate-deployment` - Validates deployment configuration
- `approval-staging` - Staging approval gate
- `approval-production` - Production approval gate
- `deploy` - Deploys manifests and updates images
- `smoke-tests` - Runs basic smoke tests
- `notify-success` - Sends success notification
- `notify-failure` - Sends failure notification

**Manual Inputs:**
- `environment` - staging or production
- `image_tag` - Specific tag or latest

**Approval Required:** ✅ Both staging and production

### 4. terraform-validate.yml
**Trigger:** Pull requests and pushes to terraform/ directory
**Purpose:** Validates infrastructure code quality and security

**Jobs:**
- `terraform-format` - Checks terraform code formatting
- `terraform-validate` - Validates terraform syntax
- `terraform-plan` - Creates plan and comments on PR
- `tflint` - Static analysis with TFLint
- `checkov` - Security scanning with Checkov
- `cost-estimation` - Estimates infrastructure costs
- `summary` - Validation summary

**Tools:**
- Terraform fmt
- TFLint for best practices
- Checkov for security policies
- Cost estimation

### 5. infrastructure-deploy.yml
**Trigger:** Manual workflow_dispatch
**Purpose:** Deploys infrastructure changes via Terraform

**Jobs:**
- `approval` - Environment approval gate
- `terraform` - Runs terraform plan/apply/destroy
- `backup-state` - Backs up terraform state
- `notify-success` - Success notification
- `notify-failure` - Failure notification

**Manual Inputs:**
- `environment` - develop, staging, or production
- `action` - plan, apply, or destroy

**Approval Required:** ✅ All environments

### 6. security-scanning.yml
**Trigger:** Pull requests, pushes to main, daily schedule (2 AM UTC)
**Purpose:** Comprehensive security scanning and compliance validation

**Jobs:**
- `dependency-check` - Checks for vulnerable dependencies
- `sast-scan` - Static application security testing with Bandit
- `container-scan` - Docker image vulnerability scanning with Trivy
- `secrets-detection` - Secret scanning with truffleHog
- `iac-security` - Infrastructure code security with Checkov
- `k8s-security` - Kubernetes manifest security with kubesec
- `network-policy-check` - Validates network policies
- `compliance-check` - AIDLC compliance verification
- `sbom-generation` - Generates software bill of materials
- `security-summary` - Summary of all security scans

**Tools:**
- Safety (Python dependency vulnerabilities)
- Bandit (Python security issues)
- Trivy (Container vulnerabilities)
- truffleHog (Secrets detection)
- Checkov (IaC security)
- kubesec (K8s security)

---

## CI/CD Flow Diagram

```
Pull Request Created
        ↓
    [test-validate.yml]
    ├─ Python lint & format
    ├─ Unit tests & coverage
    ├─ Security scanning
    ├─ Docker build
    └─ K8s validation
        ↓
    ✅ All checks pass?
        ↓ Yes
    Code review approved
        ↓
    Merge to main
        ↓
    [build-push.yml]
    ├─ Build fraud-detection
    ├─ Build frontend
    ├─ Build frontend
    └─ Push to ECR
        ↓
    GitHub release created
        ↓
    Manual trigger: [deploy.yml]
    ├─ Staging approval
    ├─ Deploy to staging
    ├─ Smoke tests
    └─ On success → Production approval
        ↓
    Deploy to production
        ↓
    [security-scanning.yml] (Daily)
    ├─ Dependency check
    ├─ SAST analysis
    ├─ Container scan
    └─ Compliance check
```

---

## Infrastructure Changes Flow

```
Modify terraform files
        ↓
    [terraform-validate.yml]
    ├─ Format check
    ├─ Validation
    ├─ Plan created
    └─ TFLint analysis
        ↓
    PR comment with plan
        ↓
    Approval & merge
        ↓
    Manual trigger: [infrastructure-deploy.yml]
        ↓
    Approval gate
        ↓
    Terraform apply
        ↓
    State backup
        ↓
    Output stored in artifacts
```

---

## Security Scanning Process

```
Code committed
        ↓
    [security-scanning.yml] triggered
    ├─ Dependency vulnerabilities
    ├─ Static code analysis (SAST)
    ├─ Container image scanning
    ├─ Secret detection
    ├─ IaC security checks
    ├─ K8s security analysis
    └─ Compliance verification
        ↓
    Reports saved to artifacts
        ↓
    GitHub Security tab updated
        ↓
    Failed checks block merge
```

---

## Environment Configuration

### Secrets Required in GitHub

```
AWS_ACCOUNT_ID                 - AWS account number
AWS_ROLE_TO_ASSUME             - IAM role for GitHub Actions
AWS_ROLE_TO_ASSUME_UAT         - (optional) Separate UAT role
AWS_ROLE_TO_ASSUME_PROD        - (optional) Separate production role
TERRAFORM_STATE_BUCKET         - S3 bucket for terraform state
KUBE_CONFIG                    - Base64-encoded kubeconfig
```

### Environment Settings

**Staging:**
- Requires approval (one reviewer)
- Auto-deploys on approval
- Allows manual trigger
- Automatic smoke tests

**Production:**
- Requires approval (two reviewers)
- Manual deployment after approval
- Extended smoke tests
- Automatic backup before changes

---

## Usage Examples

### Deploy to Staging

1. Navigate to Actions → Deploy to Staging & Production
2. Click "Run workflow"
3. Select environment: `staging`
4. Image tag: `latest` (or specific tag)
5. Click green "Run workflow"
6. Wait for approval request
7. Review and approve
8. Deployment begins automatically

### Deploy Infrastructure Changes

1. Navigate to Actions → Infrastructure Deployment
2. Click "Run workflow"
3. Select environment: `develop`/`staging`/`production`
4. Select action: `plan`/`apply`/`destroy`
5. Click "Run workflow"
6. Wait for approval
7. Review plan output
8. Approve if correct
9. Changes applied automatically

### Manual Security Scan

The security-scanning workflow runs:
- On every PR
- On every push to main
- Daily at 2 AM UTC

To run manually:
1. Navigate to Actions → Security Scanning & Compliance
2. Click "Run workflow"
3. Workflow executes immediately

---

## Monitoring & Troubleshooting

### View Workflow Status

1. **GitHub Actions Dashboard:** Actions tab → Select workflow
2. **Commit Status:** Green ✅ or Red ❌ on commit
3. **PR Status Checks:** Shows all running checks
4. **Artifacts:** Download test reports and scan results

### Common Issues

**Test failures:**
- Check test-validate logs
- Run locally: `pytest app/ -v`
- Review error output in GitHub Actions

**Build failures:**
- Check build-push logs
- Verify Docker credentials
- Check image tags in manifest

**Deployment failures:**
- Check kubeconfig validity
- Verify AWS IAM permissions
- Check resource quotas
- Review pod events

**Security scan alerts:**
- Review Bandit output
- Check Checkov policies
- Verify no secrets in code
- Update dependencies

### Debug Tips

1. **View full logs:**
   - Click workflow run
   - Expand job sections
   - View full step output

2. **Download artifacts:**
   - Artifacts section at bottom
   - Contains reports and outputs

3. **Re-run workflow:**
   - Use "Re-run failed jobs" button
   - Or re-run entire workflow

---

## Best Practices

### Code Changes

✅ **Do:**
- Make small, focused PRs
- Include tests with all changes
- Add documentation
- Update CHANGELOG
- Ensure all checks pass

❌ **Don't:**
- Bypass security scans
- Skip tests
- Commit secrets
- Force push to main
- Disable approval gates

### Infrastructure Changes

✅ **Do:**
- Review terraform plan carefully
- Backup state before changes
- Test in staging first
- Document why changes needed
- Monitor after deployment

❌ **Don't:**
- Use destroy action lightly
- Change without approval
- Ignore cost estimates
- Forget to backup state

### Deployment

✅ **Do:**
- Deploy during business hours
- Have runbooks ready
- Monitor after deployment
- Keep previous version available
- Document what was deployed

❌ **Don't:**
- Deploy multiple services simultaneously
- Skip smoke tests
- Deploy on Friday afternoon
- Deploy without approval
- Forget to notify team

---

## Troubleshooting Guide

### Pipeline Not Triggering

**Problem:** Workflow doesn't start
**Solution:**
- Check branch protection rules
- Verify workflow file syntax
- Check workflow trigger conditions
- Ensure files match path filters

### Tests Failing Locally but Passing in CI

**Problem:** Different results between local and CI
**Solution:**
- Check Python version match
- Verify all dependencies installed
- Check environment variables
- Look for path-specific issues

### Secrets Not Available in Workflow

**Problem:** `${{ secrets.SECRET_NAME }}` is empty
**Solution:**
- Verify secret exists in Settings
- Check secret name exactly matches
- Verify secret scope (repo vs org)
- Try re-entering secret value

### Terraform State Lock

**Problem:** "Error acquiring the state lock"
**Solution:**
```bash
# Unlock state
aws s3api get-object-retention \
  --bucket terraform-state \
  --key eks/terraform.tfstate
# Manual unlock may be needed
```

---

## Support & Documentation

- **GitHub Actions Docs:** https://docs.github.com/en/actions
- **Terraform Docs:** https://www.terraform.io/docs
- **Kubernetes Docs:** https://kubernetes.io/docs
- **AWS EKS Docs:** https://docs.aws.amazon.com/eks

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | June 2, 2026 | Initial comprehensive CI/CD pipeline implementation |

---

**Last Updated:** June 2, 2026  
**Maintained by:** DevOps Team  
**Contact:** devops@example.com
