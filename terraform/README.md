This folder contains Terraform code to provision:

- Azure Resource Group
- Azure Container Registry (ACR)
- Azure App Service Plan (Linux)
- Azure Linux Web App configured to pull a container from ACR

Usage (local):

1. Install Terraform and Azure CLI.
2. Authenticate with Azure: `az login` (or use a service principal).
3. From this folder run:
   terraform init
   terraform apply -var="prefix=gha2" -var="location=eastus" -auto-approve

Notes for CI (GitHub Actions):

- The workflow expects a repository secret named `AZURE_CREDENTIALS` containing a service principal JSON
  as produced by `az ad sp create-for-rbac --sdk-auth --role Contributor`.
- Workflow builds and pushes the Docker image to ACR, then updates the Web App to use the pushed image tag.
- The values `prefix`, `location`, `image_name`, and `TAG` environment variables can be adjusted in the workflow.

Using an existing ACR
---------------------

To use an existing ACR instead of creating one in Terraform, set the following Terraform variables when running:

- `use_existing_acr=true`
- `existing_acr_name=<your-acr-name>`
- `existing_acr_rg=<acr-resource-group>`

In CI, set repository secrets (or environment variables) and workflow env accordingly:

- `AZURE_ACR_NAME` - existing ACR name
- `AZURE_ACR_RG` - resource group where ACR exists

The workflow will use the provided ACR to push the Docker image. Terraform will not create a new ACR when `use_existing_acr=true`.
