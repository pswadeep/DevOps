State lives in Azure Blob (rg-acme-tfstate-<env> / stacmetf<env>001 / tfstate). Pipeline 01 creates it; 02 plans and applies; 03 validates PRs; 51 detects drift.
The `ado-service-connection` module creates workload-identity service connections (`sc-azure-<env>`).
