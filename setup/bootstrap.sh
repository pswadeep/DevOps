#!/usr/bin/env bash
# bootstrap.sh - one-time setup of the Azure DevOps project from code.
# Prereqs: az CLI, azure-devops extension (az extension add -n azure-devops), jq, logged in with project admin rights.
# Usage:   AZDO_ORG=https://dev.azure.com/acme AZDO_PROJECT=platform REPO=acme-devops-platform ./setup/bootstrap.sh
set -euo pipefail
: "${AZDO_ORG:?}"; : "${AZDO_PROJECT:?}"; REPO="${REPO:-acme-devops-platform}"; CFG=setup/project.json
az devops configure -d organization="$AZDO_ORG" project="$AZDO_PROJECT"

echo "== 1. governance (environments, plain variable groups, branch policies)"
bash scripts/azdo-sync.sh "$CFG"

echo "== 2. Key Vault-linked variable groups (needs vault + service connection first)"
for g in $(jq -r '.variableGroups[] | select(.keyVault!=null) | .name' "$CFG"); do
  echo "   $g -> create in UI: Pipelines > Library > + Variable group > Link secrets from Azure Key Vault ($(jq -r --arg g $g '.variableGroups[]|select(.name==$g)|.keyVault' "$CFG"))"
done

echo "== 3. register pipelines"
jq -c '.pipelines[]' "$CFG" | while read -r p; do
  name=$(jq -r .name <<<"$p"); file=$(jq -r .file <<<"$p")
  if az pipelines show --name "$name" >/dev/null 2>&1; then echo "   exists: $name"; continue; fi
  az pipelines create --name "$name" --yml-path "$file" --repository "$REPO" --repository-type tfsgit --branch main --skip-first-run true -o none
  echo "   created: $name"
done

echo "== 4. PR validation (Azure Repos ignores pr: triggers; use build validation)"
for slug in 03-infra-pr-validate 36-sast-sca-pr-gate 37-secret-scan-gitleaks; do
  id=$(az pipelines show --name "$slug" --query id -o tsv)
  repo_id=$(az repos show --repository "$REPO" --query id -o tsv)
  az repos policy build create --repository-id "$repo_id" --branch main --build-definition-id "$id" \
    --display-name "$slug" --blocking true --enabled true --queue-on-source-update-only true \
    --manual-queue-only false --valid-duration 720 -o none || true
done
echo "done"
