# Architecture Documentation

## System Overview

ShopMart is a production-grade, cloud-native 3-tier e-commerce application deployed
on Microsoft Azure. It is designed for high availability, security, and continuous delivery.

---

## Architecture Diagram

```
  ┌─────────────────────────────────────────────────────────────────────────────┐
  │                         AZURE CLOUD                                         │
  │                                                                              │
  │  ┌──────────────────────────────────────────────────────────────────────┐   │
  │  │  Azure Virtual Network (10.0.0.0/16)                                │   │
  │  │                                                                      │   │
  │  │  ┌─────────────────────────────────────────────────────────────┐    │   │
  │  │  │  AKS Cluster (snet-aks — 10.0.1.0/24)                      │    │   │
  │  │  │                                                             │    │   │
  │  │  │  ┌─────────────────────────────────────────────────────┐   │    │   │
  │  │  │  │  Namespace: ecommerce                               │   │    │   │
  │  │  │  │                                                     │   │    │   │
  │  │  │  │  ┌──────────────────┐  ┌──────────────────────┐    │   │    │   │
  │  │  │  │  │  Frontend Pods   │  │  Backend Pods        │    │   │    │   │
  │  │  │  │  │  (Angular/Nginx) │  │  (ASP.NET Core 8)    │    │   │    │   │
  │  │  │  │  │  Replicas: 2-10  │  │  Replicas: 2-10      │    │   │    │   │
  │  │  │  │  │  Port: 8080      │  │  Port: 8080          │    │   │    │   │
  │  │  │  │  └───────┬──────────┘  └──────────┬───────────┘    │   │    │   │
  │  │  │  │          │                         │                │   │    │   │
  │  │  │  │  ┌───────▼─────────────────────────▼───────────┐   │   │    │   │
  │  │  │  │  │  NGINX Ingress Controller (Public LB)        │   │   │    │   │
  │  │  │  │  │  TLS termination via cert-manager            │   │   │    │   │
  │  │  │  │  └─────────────────────┬───────────────────────┘   │   │    │   │
  │  │  │  └────────────────────────┼───────────────────────────┘   │    │   │
  │  │  │                           │                               │    │   │
  │  │  └───────────────────────────┼───────────────────────────────┘    │   │
  │  │                              │                                     │   │
  │  │  ┌────────────────┐          │          ┌─────────────────────┐    │   │
  │  │  │  Azure SQL DB  │◄─────────┼──────────│  Azure Key Vault    │    │   │
  │  │  │  (snet-data)   │          │          │  (secrets/certs)    │    │   │
  │  │  │  Business Tier │          │          └─────────────────────┘    │   │
  │  │  └────────────────┘          │                                     │   │
  │  │                              │          ┌─────────────────────┐    │   │
  │  │  ┌────────────────┐          │          │  Azure Monitor +    │    │   │
  │  │  │  Azure CR      │          │          │  Log Analytics      │    │   │
  │  │  │  (Container    │──────────┘          │  App Insights       │    │   │
  │  │  │   Registry)    │                     └─────────────────────┘    │   │
  │  │  └────────────────┘                                                │   │
  │  └──────────────────────────────────────────────────────────────────┘   │
  └─────────────────────────────────────────────────────────────────────────────┘
```

---

## Tier Breakdown

### Tier 1 — Presentation (Frontend)

| Attribute       | Detail                                       |
|-----------------|----------------------------------------------|
| Framework       | Angular 17 (standalone components, signals)  |
| Language        | TypeScript 5.4                               |
| UI Library      | Angular Material + Bootstrap 5               |
| Build Output    | Static files served by NGINX 1.25-alpine     |
| Container Port  | 8080                                         |
| Auth            | JWT — stored in-memory, refresh via cookie   |
| State           | Angular Signals (no NgRx)                    |
| Cart            | `localStorage`-backed client state           |

**Key features:**
- Product catalogue with category filtering, search, pagination
- Product detail with cart add
- Shopping cart with quantity management
- Checkout form with order placement
- JWT auth — login / register
- Order history

---

### Tier 2 — Application (Backend)

| Attribute       | Detail                                              |
|-----------------|-----------------------------------------------------|
| Framework       | ASP.NET Core 8 Web API                              |
| Language        | C# 12                                              |
| ORM             | Entity Framework Core 8 (code-first, migrations)   |
| Authentication  | JWT Bearer tokens (HMAC-SHA256, 60 min expiry)     |
| Validation      | FluentValidation                                    |
| Mapping         | AutoMapper                                          |
| Logging         | Serilog → Console + Application Insights           |
| Rate Limiting   | AspNetCoreRateLimit (IP-based)                     |
| Documentation   | Swagger / OpenAPI v3                               |
| Container Port  | 8080                                               |

**API Endpoints:**

| Method | Path                         | Auth      | Description              |
|--------|------------------------------|-----------|--------------------------|
| POST   | `/api/auth/register`         | Public    | Register new user        |
| POST   | `/api/auth/login`            | Public    | Authenticate user        |
| POST   | `/api/auth/refresh`          | Public    | Refresh JWT token        |
| GET    | `/api/products`              | Public    | Paginated product list   |
| GET    | `/api/products/{id}`         | Public    | Product details          |
| GET    | `/api/products/featured`     | Public    | Featured products        |
| GET    | `/api/categories`            | Public    | Category list            |
| POST   | `/api/orders`                | JWT       | Place new order          |
| GET    | `/api/orders/my-orders`      | JWT       | User's order history     |
| GET    | `/api/orders/{id}`           | JWT       | Order details            |
| PATCH  | `/api/orders/{id}/cancel`    | JWT       | Cancel order             |
| GET    | `/health`                    | Public    | Health check             |

---

### Tier 3 — Data (Database)

| Attribute            | Detail                                         |
|----------------------|------------------------------------------------|
| Service              | Azure SQL Database (Basic — 5 DTUs, 2 GB)      |
| Engine               | SQL Server 2022 compatible (v12.0)             |
| Deployment Model     | DBaaS — Managed PaaS                          |
| Connectivity         | Firewall rules (AKS subnet + VM subnet CIDRs)  |
| TLS minimum          | 1.2 enforced                                   |
| Encryption at rest   | TDE (Transparent Data Encryption) — enabled    |
| Encryption in transit| SSL/TLS enforced                              |
| Backup               | Azure automated backups (7-day retention)      |
| Geo-redundancy       | None (Basic tier; dev environment)             |
| Migrations           | EF Core code-first + SQL scripts in `database/`|

**Schema:**

```
┌─────────────┐     ┌──────────────┐     ┌────────────────┐
│  Categories │     │   Products   │     │     Users      │
│─────────────│     │──────────────│     │────────────────│
│ Id (PK)     │◄────│ CategoryId   │     │ Id (PK)        │
│ Name        │     │ Id (PK)      │     │ Email (UNIQUE) │
│ Description │     │ Name         │     │ PasswordHash   │
│ ImageUrl    │     │ Description  │     │ FirstName      │
│ IsActive    │     │ Price        │     │ LastName       │
└─────────────┘     │ DiscountPrice│     │ Role           │
                    │ ImageUrl     │     │ RefreshToken   │
                    │ Sku (UNIQUE) │     │ IsActive       │
                    │ StockQty     │     └───────┬────────┘
                    │ Rating       │             │
                    │ IsFeatured   │     ┌───────▼────────┐
                    │ IsActive     │     │     Orders     │
                    └──────────────┘     │────────────────│
                           │             │ Id (PK)        │
                           │             │ OrderNumber    │
                    ┌──────▼─────────────│ UserId (FK)    │
                    │   OrderItems  │    │ Status         │
                    │───────────────│    │ Shipping*      │
                    │ Id (PK)       │    │ Subtotal       │
                    │ OrderId (FK)  │    │ ShippingCost   │
                    │ ProductId (FK)│    │ Tax            │
                    │ ProductName   │    │ Total          │
                    │ UnitPrice     │    └────────────────┘
                    │ Quantity      │
                    │ Subtotal      │
                    └───────────────┘
```

---

## CI/CD Pipeline

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CI/CD PIPELINE FLOW                                  │
│                                                                              │
│  Developer                                                                   │
│  git push ──► GitHub ──► GitHub Actions (Self-Hosted Runner on Azure VM)    │
│                                  │                                          │
│                    ┌─────────────▼──────────────────────────┐               │
│                    │  Stage 1: Pre-Flight Security           │               │
│                    │  • Gitleaks — secret scanning          │               │
│                    └─────────────┬──────────────────────────┘               │
│                                  │                                          │
│                    ┌─────────────▼──────────────────────────┐               │
│                    │  Stage 2: Build & Test                  │               │
│                    │  • dotnet restore / npm ci             │               │
│                    │  • dotnet build / ng build:prod        │               │
│                    │  • Unit tests + code coverage          │               │
│                    │  • dotnet vuln check / npm audit SCA   │               │
│                    └─────────────┬──────────────────────────┘               │
│                                  │                                          │
│                    ┌─────────────▼──────────────────────────┐               │
│                    │  Stage 3: SAST + IaC Scan               │               │
│                    │  • SonarQube Quality Gate              │               │
│                    │  • OWASP Dependency-Check              │               │
│                    └─────────────┬──────────────────────────┘               │
│                                  │                                          │
│                    ┌─────────────▼──────────────────────────┐               │
│                    │  Stage 4: Container Build & Scan        │               │
│                    │  • docker build (multi-stage)          │               │
│                    │  • Trivy filesystem scan               │               │
│                    │  • Trivy image scan (fail on CRITICAL) │               │
│                    └─────────────┬──────────────────────────┘               │
│                                  │                                          │
│                    ┌─────────────▼──────────────────────────┐               │
│                    │  Stage 5: Publish                       │               │
│                    │  • Push image → Azure Container Registry│               │
│                    │  • Package artifact → Nexus Repository │               │
│                    └─────────────┬──────────────────────────┘               │
│                                  │  (main branch only)                      │
│                    ┌─────────────▼──────────────────────────┐               │
│                    │  Stage 6: Deploy to AKS                 │               │
│                    │  • Checkov IaC scan                    │               │
│                    │  • kubectl apply (rolling update)      │               │
│                    │  • Rollout status wait                 │               │
│                    │  • Auto-rollback on failure            │               │
│                    └─────────────┬──────────────────────────┘               │
│                                  │                                          │
│                    ┌─────────────▼──────────────────────────┐               │
│                    │  Stage 7: Post-Deploy DAST              │               │
│                    │  • OWASP ZAP baseline scan (UI)        │               │
│                    │  • OWASP ZAP API scan (REST)           │               │
│                    │  • Alert Slack on findings             │               │
│                    └────────────────────────────────────────┘               │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## DevSecOps Coverage Matrix

| Layer           | Threat                        | Tool                   | Stage       | Response on Finding    |
|-----------------|-------------------------------|------------------------|-------------|------------------------|
| Source Code     | Hardcoded secrets/keys        | Gitleaks               | Pre-build   | Fail build, Slack alert|
| Source Code     | Code vulnerabilities (SAST)   | SonarQube              | Build       | Fail on Quality Gate   |
| Dependencies    | Known CVEs (npm)              | npm audit              | Build       | Fail on critical       |
| Dependencies    | Known CVEs (.NET)             | dotnet vuln            | Build       | Fail on critical       |
| Dependencies    | Transitive CVEs               | OWASP Dep-Check        | Build       | Fail on CVSS ≥ 8       |
| Container       | OS/package CVEs               | Trivy                  | Post-build  | Fail on CRITICAL       |
| Container       | Misconfig (Dockerfile)        | Checkov                | Post-build  | Warn on HIGH           |
| Infrastructure  | K8s misconfigurations         | Checkov                | Pre-deploy  | Warn on HIGH           |
| Infrastructure      | Bicep/ARM misconfigurations   | Checkov                | Pre-deploy  | Warn on HIGH           |
| Runtime (DAST)  | OWASP Top 10 web vulns        | OWASP ZAP              | Post-deploy | Slack alert on HIGH    |
| Runtime         | Secrets in running pods       | Azure Defender         | Continuous  | Azure Security alerts  |
| Runtime         | Anomaly detection             | Azure Sentinel         | Continuous  | SIEM alert             |

---

## Kubernetes Architecture

### Resource Structure

```
Namespace: ecommerce
├── Deployments
│   ├── ecommerce-frontend  (2 replicas min)
│   └── ecommerce-backend   (2 replicas min)
├── Services
│   ├── ecommerce-frontend-svc  (ClusterIP)
│   └── ecommerce-backend-svc  (ClusterIP)
├── Ingress
│   └── ecommerce-ingress  (NGINX, TLS)
├── HPA (Horizontal Pod Autoscaler)
│   ├── frontend-hpa  (2-10 replicas, 70% CPU)
│   └── backend-hpa   (2-10 replicas, 70% CPU)
├── PodDisruptionBudgets
│   ├── frontend-pdb  (minAvailable: 1)
│   └── backend-pdb   (minAvailable: 1)
├── ConfigMaps
│   └── app-config
└── Secrets
    ├── ecommerce-secrets  (sql, jwt)
    └── acr-pull-secret
```

### Pod Security

- All containers run as **non-root** user (UID 1001)
- `readOnlyRootFilesystem: true` where possible
- `allowPrivilegeEscalation: false`
- `seccompProfile: RuntimeDefault`
- Resource limits and requests defined on all containers
- Image pull always from ACR (never `:latest` in production manifests)

---

## Networking & Security Boundaries

```
Internet
    │
    ▼
Azure Application Gateway / Front Door (WAF)
    │  (TLS 1.2+ only, OWASP CRS ruleset)
    │
    ▼
NGINX Ingress Controller (AKS)
    │  (routes /, /api/*)
    ├──► ecommerce-frontend-svc ──► Frontend Pods
    └──► ecommerce-backend-svc  ──► Backend Pods
                                         │
                                         │ (Private Endpoint only)
                                         ▼
                                  Azure SQL Database
                                  (snet-data — no public access)
```

**Network Security Groups (NSGs) — managed by Terraform (`terraform/modules/networking/`):**

| Rule                  | Direction | Source                | Destination         | Port(s)        |
|-----------------------|-----------|-----------------------|---------------------|----------------|
| AllowHttps            | Inbound   | Internet              | AKS Load Balancer   | 443            |
| AllowHttp             | Inbound   | Internet              | AKS Load Balancer   | 80             |
| AllowBastionSsh       | Inbound   | AzureBastionSubnet    | snet-vm             | 22             |
| AllowVnetInbound      | Inbound   | VirtualNetwork        | snet-vm             | 8080,8081,9000 |
| DenyAllInternetInbound| Inbound   | Internet              | snet-vm             | *              |
| Allow AKS→SQL         | Outbound  | snet-aks (service ep) | Azure SQL           | 1433           |
| Allow VM→SQL          | Outbound  | snet-vm (service ep)  | Azure SQL           | 1433           |
| Allow KV access       | Outbound  | snet-vm (service ep)  | Azure Key Vault     | 443            |

---

## Observability Stack

| Component         | Service                        | Purpose                         |
|-------------------|--------------------------------|---------------------------------|
| APM               | Azure Application Insights     | Request tracing, exceptions     |
| Logs              | Azure Log Analytics            | Centralised log aggregation     |
| Metrics           | Azure Monitor                  | CPU, memory, network metrics    |
| K8s Metrics       | Prometheus + Grafana (via Helm)| Pod/container level metrics     |
| Alerts            | Azure Monitor Alert Rules      | CPU > 80%, error rate > 1%      |
| Security          | Microsoft Defender for Cloud   | Runtime threat protection       |
| SIEM              | Azure Sentinel (optional)      | Security event correlation      |

---

## High Availability Design

| Component          | HA Strategy                                           |
|--------------------|-------------------------------------------------------|
| Frontend Pods      | Min 2 replicas (HPA: 2–10)                            |
| Backend Pods       | Min 2 replicas (HPA: 2–10)                            |
| AKS Node Pool      | 1 node, Free tier (`Standard_D2ls_v5`, Central India) |
| Azure SQL          | Basic tier — no zone redundancy (dev environment)     |
| ACR                | Basic SKU — LRS storage                               |
| Ingress            | NGINX with 2 replicas                                 |
| PodDisruptionBudget| `minAvailable: 1` — ensures no full outage on drain   |
| HPA                | Scales 2→10 replicas based on CPU/RPS                 |
| Rollback           | Automatic on GitHub Actions deploy failure            |

---

## Secrets Management

```
Source of Truth: Azure Key Vault
         │
         ├── SQL Connection String
         ├── JWT Secret Key
         ├── ACR credentials
         └── Application Insights key
              │
              ▼
    AKS: Secrets Store CSI Driver
    (mounts Key Vault secrets as K8s Secrets)
              │
              ▼
    K8s Secret: ecommerce-secrets
    (injected as environment variables into pods)
```

GitHub Actions secrets are used **only** for pipeline operations (deploying,
pushing images). Application runtime secrets come from Key Vault → K8s Secrets.

---

## Infrastructure as Code

All Azure infrastructure is provisioned with **Terraform** (modules in `terraform/`).

| Module             | Resources created                                         |
|--------------------|-----------------------------------------------------------|
| `networking/`      | VNet (10.0.0.0/16), 4 subnets, NSGs, associations         |
| `keyvault/`        | Key Vault (Standard), initial secrets                     |
| `acr/`             | Container Registry (Basic SKU)                            |
| `aks/`             | AKS cluster (Free tier, 1 node), AcrPull role assignment  |
| `build_vm/`        | Ubuntu 22.04 VM, NIC (no public IP), cloud-init script    |
| `sql/`             | SQL Server v12, Basic DB (5 DTU, 2 GB), firewall rules    |
| `bastion/`         | Public IP (Standard), Bastion host (Basic SKU)            |

**Remote state** is stored in Azure Blob Storage (provisioned by
`terraform/scripts/create-remote-backend.sh` before first `terraform apply`).

---

## Branching Strategy

```
main          ──── Protected ── CI/CD → Production AKS
  │
  └── develop ──── CI/CD → Staging (optional)
        │
        └── feature/*  ── CI only (build + scan, no deploy)
        └── fix/*       ── CI only
        └── hotfix/*    ── CI + deploy to Production (manual trigger)
```

**Branch protection rules on `main`:**
- Require PR reviews (minimum 1)
- Require all CI status checks to pass
- Require linear history
- No force pushes
