# 3-Tier E-Commerce Application — Production Grade

## Overview

A production-grade, cloud-native 3-tier e-commerce platform built on:

| Tier       | Technology             | Hosting                        |
|------------|------------------------|--------------------------------|
| Frontend   | Angular 17             | AKS (containerised via Nginx)  |
| Backend    | ASP.NET Core 8 Web API | AKS (containerised)            |
| Database   | Azure SQL Database      | DBaaS (managed PaaS)           |

---

## Repository Structure

```
3-tier-application-workflow/
├── frontend/                   # Angular 17 SPA (e-commerce UI)
│   ├── src/
│   ├── Dockerfile
│   └── nginx.conf
├── backend/                    # ASP.NET Core 8 REST API
│   ├── src/ECommerceAPI/
│   └── Dockerfile
├── database/                   # Azure SQL migration scripts
│   └── migrations/
├── k8s/                        # Kubernetes manifests for AKS
│   ├── namespace.yaml
│   ├── frontend/
│   ├── backend/
│   ├── ingress/
│   ├── configmaps/
│   └── secrets/
├── infrastructure/             # Azure Bicep IaC templates
│   ├── main.bicep
│   ├── modules/
│   └── parameters/
├── .github/
│   └── workflows/
│       ├── frontend-ci.yml     # Frontend build + security + Nexus publish
│       ├── backend-ci.yml      # Backend build + security + Nexus publish
│       ├── security-scan.yml   # Scheduled DevSecOps scans
│       └── deploy-aks.yml      # CD — deploy to AKS
└── docs/
    ├── build-server-setup.md   # Azure VM build server & tools installation
    └── architecture.md         # Architecture overview & diagrams
```

---

## CI/CD Pipeline Architecture

```
Developer Push
     │
     ▼
GitHub Actions (Self-Hosted Runner on Azure VM)
     │
     ├─► Gitleaks  (Secret Scanning)
     ├─► npm audit / dotnet list --vulnerable  (SCA)
     ├─► SonarQube SAST  (Code Quality + Security)
     ├─► OWASP Dependency-Check
     ├─► Build & Unit Tests
     ├─► Docker Build
     ├─► Trivy  (Container Image Scanning)
     ├─► Push to Azure Container Registry (ACR)
     ├─► Publish Artifact → Nexus Repository
     └─► Deploy to AKS (on main branch only)
          │
          └─► OWASP ZAP DAST  (Post-deployment)
```

---

## Prerequisites

- Azure Subscription
- Azure CLI installed
- kubectl installed
- Helm 3 installed
- Docker Desktop (local dev)

---

## Quick Start — Local Development

### Frontend
```bash
cd frontend
npm install
npm start          # Runs at http://localhost:4200
```

### Backend
```bash
cd backend/src/ECommerceAPI
dotnet restore
dotnet run         # Runs at http://localhost:5000
```

---

## Infrastructure Provisioning

```bash
cd infrastructure
az login
az deployment sub create \
  --location eastus \
  --template-file main.bicep \
  --parameters @parameters/prod.parameters.json
```

---

## Required GitHub Secrets

| Secret Name                    | Description                             |
|--------------------------------|-----------------------------------------|
| `ACR_LOGIN_SERVER`             | Azure Container Registry login URL      |
| `ACR_USERNAME`                 | ACR admin username                      |
| `ACR_PASSWORD`                 | ACR admin password                      |
| `AKS_RESOURCE_GROUP`           | AKS resource group name                 |
| `AKS_CLUSTER_NAME`             | AKS cluster name                        |
| `AZURE_CREDENTIALS`            | Azure service principal JSON            |
| `SONAR_TOKEN`                  | SonarQube authentication token          |
| `SONAR_HOST_URL`               | SonarQube server URL                    |
| `NEXUS_URL`                    | Nexus Repository Manager URL            |
| `NEXUS_USERNAME`               | Nexus username                          |
| `NEXUS_PASSWORD`               | Nexus password                          |
| `SQL_CONNECTION_STRING`        | Azure SQL connection string             |
| `SLACK_WEBHOOK_URL`            | Slack webhook for security notifications|

---

## DevSecOps Coverage

| Category               | Tool                        | Stage         |
|------------------------|-----------------------------|---------------|
| Secret Scanning        | Gitleaks                    | Pre-build     |
| SAST                   | SonarQube                   | Build         |
| SCA (Frontend)         | npm audit, OWASP Dep-Check  | Build         |
| SCA (Backend)          | dotnet vulnerability, OWASP | Build         |
| Container Scanning     | Trivy                       | Post-build    |
| IaC Security           | Checkov                     | Build         |
| DAST                   | OWASP ZAP                   | Post-deploy   |
| Compliance Reporting   | SonarQube Quality Gate      | Build         |

---

## See Also

- [Build Server Setup Guide](docs/build-server-setup.md)
- [Architecture Documentation](docs/architecture.md)
