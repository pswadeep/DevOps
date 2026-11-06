# bootstrap.ps1 - Windows PowerShell version of bootstrap.sh
# Prereqs: az CLI + azure-devops extension; logged in (az login). Run from the repo root.
param(
  [Parameter(Mandatory)] [string]$Org,        # https://dev.azure.com/acme
  [Parameter(Mandatory)] [string]$Project,    # platform
  [string]$Repo = "acme-devops-platform"
)
$ErrorActionPreference = "Stop"
az devops configure -d organization=$Org project=$Project
$cfg = Get-Content setup/project.json -Raw | ConvertFrom-Json

Write-Host "== 1. environments and plain variable groups"
foreach ($e in $cfg.environments) {
  $body = @{ name = $e.name } | ConvertTo-Json -Compress
  $tmp = New-TemporaryFile; Set-Content $tmp $body
  az devops invoke --area distributedtask --resource environments --http-method POST `
    --route-parameters project=$Project --api-version 7.1 --in-file $tmp 2>$null | Out-Null
}
foreach ($g in ($cfg.variableGroups | Where-Object { -not $_.keyVault })) {
  $id = az pipelines variable-group list --group-name $g.name --query "[0].id" -o tsv
  if (-not $id) { az pipelines variable-group create --name $g.name --authorize true --variables placeholder=replace-me -o none }
}

Write-Host "== 2. Key Vault-linked groups: create in the UI (Pipelines > Library > Link secrets from an Azure key vault)"
$cfg.variableGroups | Where-Object { $_.keyVault } | ForEach-Object { Write-Host ("   {0} -> {1}" -f $_.name, $_.keyVault) }

Write-Host "== 3. register pipelines"
foreach ($p in $cfg.pipelines) {
  $exists = az pipelines show --name $p.name 2>$null
  if ($exists) { Write-Host "   exists: $($p.name)"; continue }
  az pipelines create --name $p.name --yml-path $p.file --repository $Repo --repository-type tfsgit --branch main --skip-first-run true -o none
  Write-Host "   created: $($p.name)"
}

Write-Host "== 4. PR validation policies"
$repoId = az repos show --repository $Repo --query id -o tsv
foreach ($slug in "03-infra-pr-validate","36-sast-sca-pr-gate","37-secret-scan-gitleaks") {
  $id = az pipelines show --name $slug --query id -o tsv
  az repos policy build create --repository-id $repoId --branch main --build-definition-id $id --display-name $slug `
    --blocking true --enabled true --queue-on-source-update-only true --manual-queue-only false --valid-duration 720 -o none
}
Write-Host "done"
