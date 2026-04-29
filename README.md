# docker-compose-app

A simple tasks app built with FastAPI + PostgreSQL + static HTML/JS frontend, used as a reference project for learning different deployment strategies — from a single laptop all the way to a managed Kubernetes cluster on AWS.

## Stack

| Layer     | Technology         |
|-----------|--------------------|
| Frontend  | HTML/JS + Nginx    |
| Backend   | Python + FastAPI   |
| Database  | PostgreSQL 16      |

---

## Deployment options

This repo supports five deployment scenarios. Pick the one that matches your environment.

### 1. Local development — `docker-compose.yml`

Builds images from source on your machine. All three services (frontend, backend, db) run in Docker on localhost.

**Requirements:** Docker Desktop

```bash
cp .env.example .env          # fill in your values
docker compose up -d --build
# open http://localhost
docker compose down           # stop
docker compose down -v        # stop and delete the database volume
```

---

### 2. Single server (VPS / EC2) — `docker-compose.prod.yml`

Pulls pre-built images from GitHub Container Registry (GHCR). No build step on the server — GitHub Actions builds and pushes images on every merge to `main`.

**Requirements:** Docker + Docker Compose on the server, a `.env` file

```bash
# on the server
cp .env.example .env          # fill in GITHUB_USER, GITHUB_REPO, DB credentials
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

---

### 3. Docker Swarm (multi-node) — `docker-compose.swarm.yml`

Same images as prod, but deployed as a Swarm stack across multiple nodes. Uses overlay networks so containers on different machines can talk to each other. The database is pinned to the manager node so its volume is always accessible.

**Requirements:** A Docker Swarm cluster (`docker swarm init` on the manager, `docker swarm join` on workers)

```bash
# on the manager node
docker stack deploy -c docker-compose.swarm.yml app
docker stack ls
docker stack rm app           # tear down
```

---

### 4. AWS ECS (Fargate) — `terraform/`

Deploys the app to AWS Elastic Container Service using Fargate (serverless containers). Terraform provisions the VPC, ECS cluster, task definitions, ALB, and RDS database.

**Requirements:** AWS CLI configured, Terraform installed

```bash
cd terraform
terraform init
terraform apply
# Terraform outputs the ALB URL when done
terraform destroy             # tear down and stop charges
```

---

### 5. AWS EKS (Kubernetes) — `terraform-eks/` + `k8s/`

Deploys the app to AWS Elastic Kubernetes Service. Terraform provisions the VPC, EKS cluster, managed node group, and RDS database. Kubernetes manifests in `k8s/` define the deployments, services, and autoscaling.

Features: HPA (scales backend pods on CPU), Cluster Autoscaler (scales EC2 nodes when pods are pending).

**Requirements:** AWS CLI configured, Terraform installed, kubectl installed

```bash
cd terraform-eks
terraform init
terraform apply

# after apply completes, run the setup script from the repo root:
cd ..
bash setup-eks.sh

# get the frontend URL:
kubectl get service frontend -n app

# tear down (run teardown script first — cleans up Kubernetes-managed AWS resources
# like the ELB and its security group before Terraform removes the VPC):
bash teardown-eks.sh
cd terraform-eks && terraform destroy
```

---

## CI/CD

GitHub Actions (`.github/workflows/ci-cd.yml`) runs on every push to `main`:
1. Runs backend tests
2. Builds Docker images for frontend and backend
3. Pushes them to GHCR as `ghcr.io/<user>/<repo>-frontend:latest` and `ghcr.io/<user>/<repo>-backend:latest`

The prod and Swarm deployments pull these images. EKS deployments also use these same GHCR images.

---

## Project structure

```
docker_compose/
├── docker-compose.yml           # local dev
├── docker-compose.prod.yml      # single server
├── docker-compose.swarm.yml     # Docker Swarm
├── setup-eks.sh                 # EKS post-apply setup script
├── .env.example
├── backend/
│   ├── Dockerfile
│   ├── main.py
│   └── requirements.txt
├── frontend/
│   ├── Dockerfile
│   ├── nginx.conf
│   └── index.html
├── terraform/                   # ECS infrastructure
└── terraform-eks/               # EKS infrastructure
    └── (pairs with k8s/)
k8s/                             # Kubernetes manifests
├── namespace.yaml
├── secret.yaml
├── backend-deployment.yaml
├── backend-service.yaml
├── backend-hpa.yaml
├── frontend-deployment.yaml
├── frontend-service.yaml
└── cluster-autoscaler.yaml
```
