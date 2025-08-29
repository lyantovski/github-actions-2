# Azure Web App CI/CD with GitHub Actions, Docker, and Terraform

This project demonstrates a complete CI/CD pipeline for deploying a containerized web application to Azure App Service using GitHub Actions, Docker, and Terraform. It supports both creating a new Azure Container Registry (ACR) or using an existing one, and provisions all required Azure resources via Terraform.

## Features
- **CI/CD with GitHub Actions**: Automated build, push, and deploy pipeline.
- **Dockerized App**: Multi-stage Docker build for a static web app served by hardened Nginx.
- **Terraform IaC**: Provisions Azure Resource Group, ACR (optional), App Service Plan, Linux Web App, and role assignments.
- **Flexible ACR Support**: Use an existing ACR (by name, resource group, id, or login server) or let Terraform create a new one.
- **Manual Approval**: Terraform apply is gated by GitHub environment protection for safe production deployments.
- **Secure Secrets**: All credentials and sensitive values are managed via GitHub repository secrets.

## Project Structure
```
.github/workflows/azure-deploy.yml   # Main CI/CD workflow
Dockerfile                          # Multi-stage build for Nginx static site
src/, public/, index.html           # App source and static assets
terraform/                          # Terraform configuration
  main.tf, variables.tf, outputs.tf
```

## Prerequisites
- Azure subscription with permissions to create resources and assign roles
- GitHub repository with the following secrets set:
  - `AZURE_CREDENTIALS`: Azure service principal credentials (JSON)
  - `AZURE_ACR_NAME` and `AZURE_ACR_RG`: (if using existing ACR)
  - `AZURE_ACR_ID`: (optional, if using existing ACR by resource id)
  - `ACR_USERNAME` and `ACR_PASSWORD`: (if using ACR admin credentials)

## How It Works
1. **Build & Push**: GitHub Actions builds the Docker image and pushes it to ACR.
2. **Terraform Plan**: Runs `terraform plan` with all required variables, using the resolved ACR login server.
3. **Manual Approval**: `terraform apply` is gated by the `production` environment for manual review.
4. **Deploy**: Terraform provisions/updates the Azure App Service to run the new image.

## Key Workflow Steps
- **resolve-and-build**: Resolves ACR login server, builds and pushes Docker image.
- **terraform-init/plan/apply**: Initializes, plans, and applies Terraform configuration. Plan/apply use the same lockfile and Terraform version for reproducibility.
- **Manual Approval**: The `terraform-apply` job requires approval in the GitHub `production` environment.

## Customization
- Edit `terraform/variables.tf` to adjust defaults (location, image name, etc).
- The Dockerfile and Nginx config are set up for static SPA hosting; adapt as needed for your app.
- To use an existing ACR, set the appropriate secrets (`AZURE_ACR_NAME`, `AZURE_ACR_RG`, or `AZURE_ACR_ID`).


## Usage Example

### 1. Configure GitHub Secrets
Set the following secrets in your repository:
- `AZURE_CREDENTIALS`: Azure service principal credentials (JSON)
- `AZURE_ACR_NAME` and `AZURE_ACR_RG`: (if using existing ACR)
- `AZURE_ACR_ID`: (optional, if using existing ACR by resource id)
- `ACR_USERNAME` and `ACR_PASSWORD`: (if using ACR admin credentials)

### 2. Push Code to Main Branch
Commit and push your changes to the `main` branch. The GitHub Actions workflow will:
- Build and push the Docker image to ACR
- Run `terraform plan` and upload the plan for review
- Wait for manual approval in the `production` environment
- Apply the Terraform plan to deploy/update the Azure Web App

### 3. Manual Approval
Go to the Actions tab in GitHub, select the running workflow, and approve the `terraform-apply` job when prompted.

### 4. Verify Deployment
After apply, your app will be live at the Azure Web App URL (see the output in the workflow logs or Azure Portal).

### 5. Running Terraform Locally
You can test Terraform locally:
```sh
cd terraform
terraform init
terraform plan -var="use_existing_acr=true" -var="existing_acr_id=/subscriptions/0000-0000-0000/resourceGroups/myRg/providers/Microsoft.ContainerRegistry/registries/myAcr"
```

## Security & Best Practices
- The pipeline assigns the AcrPull role to the App Service's managed identity. The service principal used must have `roleAssignments/write` permission.
- All sensitive values are passed via secrets and never hardcoded.
- The Docker image is built with a minimal, secure Nginx config and dynamic port support for Azure.

## Troubleshooting
- If `DOCKER_REGISTRY_SERVER_URL` or `DOCKER_CUSTOM_IMAGE_NAME` are empty, check your ACR secrets and Terraform variable wiring.
- Ensure the GitHub `production` environment exists and has approvers set for manual apply.
- If Terraform apply fails with lockfile or provider errors, ensure plan and apply use the same Terraform version and lockfile (the workflow handles this by default).

## License
MIT
