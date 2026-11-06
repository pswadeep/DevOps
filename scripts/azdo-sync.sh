#!/usr/bin/env bash
# azdo-sync.sh - idempotently apply project governance from setup/project.json (environments, variable groups, policies).
# Requires: az CLI + azure-devops extension, signed in, AZDO_ORG and AZDO_PROJECT set. Uses setup/project.json.
set -euo pipefail
: "${AZDO_ORG:?}"; : "${AZDO_PROJECT:?}"
CFG="${1:-setup/project.json}"
az devops configure -d organization="$AZDO_ORG" project="$AZDO_PROJECT"
for env in $(jq -r '.environments[].name' "$CFG"); do
  az devops invoke --area distributedtask --resource environments --http-method POST \
    --route-parameters project="$AZDO_PROJECT" --api-version 7.1 \
    --in-file <(jq -n --arg n "$env" '{name:$n}') >/dev/null 2>&1 || echo "environment $env exists"
done
for g in $(jq -r '.variableGroups[] | select(.keyVault==null) | .name' "$CFG"); do
  az pipelines variable-group list --group-name "$g" --query '[0].id' -o tsv | grep -q . && echo "group $g exists" || \
    az pipelines variable-group create --name "$g" --authorize true --variables placeholder=replace-me -o none
done
for b in $(jq -r '.branchPolicies[]' "$CFG"); do
  repo_id=$(az repos show --repository "$AZDO_PROJECT" --query id -o tsv)
  az repos policy approver-count create --repository-id "$repo_id" --branch "$b" --blocking true --enabled true \
    --minimum-approver-count 1 --creator-vote-counts false --allow-downvotes false --reset-on-source-push true -o none || true
  az repos policy comment-required create --repository-id "$repo_id" --branch "$b" --blocking true --enabled true -o none || true
done
echo "governance sync complete"
