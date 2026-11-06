# acme-devops-platform

Project-as-code for an Azure DevOps organisation: **55 YAML pipelines**, shared templates, IaC (Terraform + Bicep), Helm/Kustomize/Argo CD manifests, small app stubs and bootstrap scripts.
Environments: `dev`, `stage`, `prod` (prod has approvals and checks on the Azure DevOps Environment).

> Status: the pipelines were written and statically checked (YAML parse, template paths, cron syntax). They have **not** been run against a live Azure tenant. Expect to adjust names, SKUs, subscription IDs and task inputs on first run.

## Layout
- `pipelines/<group>/NN-slug.yml` - one file per pipeline
- `templates/steps|stages` - reusable templates (build-docker, deploy-env, terraform, smoke-test, notify-teams, aks-run)
- `infra/` terraform, bicep, messaging, policy, storage - `k8s/` helm, kustomize, argocd, cronjobs, bluegreen
- `apps/ libs/ db/ adf/ ml/ tests/` - small stubs the pipelines build and deploy
- `setup/project.json` - the single list of environments, variable groups and pipelines; `setup/bootstrap.sh|ps1` registers them

## Setup order
1. Create the Azure DevOps project `platform` and push this repo to it.
2. Run pipeline 01 once from a local terraform (or `az`) to create state storage, then create service connections `sc-azure-dev|stage|prod` (workload identity federation) and `sc-acr-shared`.
3. Run `setup/bootstrap.ps1 -Org https://dev.azure.com/acme -Project platform` (Windows) or `setup/bootstrap.sh`.
4. Create the Key Vault-linked groups `vg-kv-<env>` in Pipelines > Library; fill `vg-shared` and `vg-<env>` (names listed in the PDF).
5. Add approvals/checks on Environment `prod`.

## Pipelines
| # | slug | group | trigger | environments |
|---|---|---|---|---|
| 01 | `infra-bootstrap-tfstate` | foundation | Manual | dev, stage, prod (parameter) |
| 02 | `infra-terraform-plan-apply` | foundation | CI on main, paths infra/terraform/** | dev > stage > prod |
| 03 | `infra-pr-validate` | foundation | PR via branch policy, paths infra/** | validates dev only (no apply) |
| 04 | `azdo-governance-sync` | foundation | CI on main (setup/**) and weekly | project-wide |
| 05 | `bicep-landing-zone` | foundation | CI on main, paths infra/bicep/** | dev > stage > prod |
| 06 | `fe-react-static-web-app` | frontend | CI on main, paths apps/web/** | dev > stage > prod |
| 07 | `fe-react-blob-frontdoor` | frontend | CI on main, paths apps/web/** | dev > stage > prod |
| 08 | `fe-angular-webapp-linux` | frontend | CI on main, paths apps/portal/** | dev > stage > prod |
| 09 | `fe-nginx-container-aci` | frontend | Manual or branch feature/* | dev (and short-lived previews) |
| 10 | `fe-nextjs-container-webapp` | frontend | CI on main, paths apps/storefront/** | dev > stage > prod |
| 11 | `be-dotnet-webapp-slot-swap` | backend | CI on main, paths apps/payments-api/** | dev (direct) > stage (slot swap) > prod (slot swap) |
| 12 | `be-node-container-webapp` | backend | CI on main, paths apps/orders-api/** | dev > stage > prod |
| 13 | `be-python-function-app` | backend | CI on main, paths apps/ingest-func/** | dev > stage > prod |
| 14 | `be-java-aks-helm` | backend | CI on main, paths apps/inventory-service/** | dev > stage > prod |
| 15 | `api-container-aci` | backend | CI on main, paths apps/partner-api/** | dev > stage (prod uses AKS, see 14, 19) |
| 16 | `api-container-apps` | backend | CI on main, paths apps/catalog-api/** | dev > stage > prod |
| 17 | `api-apim-publish` | backend | CI on main, paths apps/orders-api/openapi/** | dev > stage > prod |
| 18 | `api-contract-tests-newman` | backend | When 'be-node-container-webapp' completes deploy_stage | stage |
| 19 | `aks-rolling-helm-multienv` | aks | CI on main, paths apps/orders-api/** | dev > stage > prod |
| 20 | `aks-canary` | aks | CI on main, paths apps/pricing/** | stage > prod |
| 21 | `aks-blue-green` | aks | Manual with parameters | stage, prod |
| 22 | `aks-gitops-argocd-tag-bump` | aks | CI on main, paths apps/orders-api/** | dev (auto commit) > stage, prod (pull request) |
| 23 | `aks-kustomize-overlays` | aks | CI on main, paths k8s/kustomize/** | dev > stage > prod |
| 24 | `aks-cluster-upgrade` | aks | Manual (parameter targetVersion) | dev > stage > prod |
| 25 | `acr-build-scan-promote` | containers | CI on main, paths apps/**/Dockerfile | dev registry > prod registry |
| 26 | `helm-chart-oci-publish` | containers | CI on main, paths k8s/helm/** | shared registry |
| 27 | `cron-acr-retention-cleanup` | containers | Schedule: Sunday 21:00 UTC (Monday 02:30 IST) | shared registry |
| 28 | `blob-storage-config-sync` | data | CI on main, paths infra/storage/** | dev > stage > prod |
| 29 | `sql-dacpac-deploy` | data | CI on main, paths db/schema/** | dev > stage > prod |
| 30 | `sql-ef-migrations` | data | CI on main, paths apps/payments-api/**/Migrations/** | dev > stage > prod |
| 31 | `adf-ci-cd` | data | CI on main, paths adf/** | dev > stage > prod |
| 32 | `servicebus-eventhub-bicep` | data | CI on main, paths infra/messaging/** | dev > stage > prod |
| 33 | `keyvault-provision-seed` | security | Manual | dev, stage, prod (parameter) |
| 34 | `cron-keyvault-secret-rotation` | security | Schedule: 1st of month 22:00 UTC | dev, stage, prod |
| 35 | `cron-keyvault-expiry-monitor` | security | Schedule: daily 06:00 UTC | dev, stage, prod |
| 36 | `sast-sca-pr-gate` | security | PR via branch policy | all code (no deployment) |
| 37 | `secret-scan-gitleaks` | security | PR (branch policy) and schedule daily 02:00 UTC | all repositories |
| 38 | `azure-policy-as-code` | security | CI on main, paths infra/policy/** | dev (audit) > stage > prod (deny) |
| 39 | `npm-publish-azure-artifacts` | artifacts | CI on main and feature branches, paths libs/ui/** | feed views @Local, @Prerelease, @Release |
| 40 | `nuget-publish-azure-artifacts` | artifacts | CI on main, paths libs/logging/** | feed views |
| 41 | `universal-package-promote` | artifacts | CI on main, paths apps/portal/** | dev > stage > prod |
| 42 | `cron-artifact-feed-retention` | artifacts | Schedule: Saturday 20:00 UTC | org feed |
| 43 | `release-semver-tag-notes` | release | Manual | n/a (tags the repo) |
| 44 | `hotfix-fast-track` | release | CI on hotfix/* | stage > prod |
| 45 | `rollback-pipeline` | release | Manual | dev, stage or prod (parameter) |
| 46 | `e2e-microservice-dev-stage-prod` | e2e | CI on main, paths apps/orders-api/** | dev > stage > prod |
| 47 | `cron-nightly-dev-shutdown` | cron | Schedule: Mon-Fri 18:00 UTC (23:30 IST, 19:00 CET winter) | dev, stage |
| 48 | `cron-morning-dev-start` | cron | Schedule: Mon-Fri 05:00 UTC (10:30 IST) | dev, stage |
| 49 | `cron-cost-anomaly-report` | cron | Schedule: Monday 04:00 UTC | all subscriptions |
| 50 | `cron-stale-resource-cleanup` | cron | Schedule: daily 21:00 UTC | dev subscription |
| 51 | `cron-terraform-drift-detect` | cron | Schedule: daily 01:00 UTC | dev, stage, prod |
| 52 | `cron-sql-backup-restore-verify` | cron | Schedule: 1st of month 23:00 UTC | prod (restore into scratch DB in dev server) |
| 53 | `perf-load-test-k6` | quality | Manual and schedule: Wednesday 22:00 UTC | stage |
| 54 | `ml-yolo-model-package-aci` | ml | CI on main, paths ml/yolo/** | dev > stage > prod |
| 55 | `cron-weekly-dependency-audit` | cron | Schedule: Monday 03:00 UTC | all repos |
