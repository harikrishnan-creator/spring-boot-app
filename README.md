# Spring Boot App - CI/CD Pipeline Documentation

## Overview
This document explains the complete CI/CD pipeline for the Spring Boot Employee Service application. The pipeline automates the process from development through to deployment on AWS infrastructure, including EKS (Elastic Kubernetes Service) and container orchestration.

**Project:** Employee Service  
**Repository:** harikrishnan-creator/spring-boot-app  
**Purpose:** DevOps practice project - Cloud app using AWS  
**Latest Commit:** c4fe710b746e5058e0d6543e8d26f4e614b1cfd1  
**Last Updated:** 2026-08-26 (Service port changed from 80 to 3006)

---

## Application working model

<img width="1536" height="1024" alt="Designer" src="https://github.com/user-attachments/assets/7ad05d46-c53d-4d7e-be7c-afdba3ea28e9" />

## Pipeline Architecture

```
Develop → Build → SonarQube Check → Docker Image → Push to ECR → Deploy to EKS/S3
```

---

## Pipeline Stages

### 1. **Develop**
**Description:** Development stage where code is written and committed to the repository.

**Trigger:** Manual workflow dispatch or push to main branch

**Key Points:**
- Source code is stored in the Git repository
- All changes are version controlled
- Ready for automated builds

---

### 2. **Build (Maven)**
**Description:** Compile and package the Spring Boot application using Maven.

**Command:**
```bash
mvn clean package
```

**Details:**
- **Clean:** Removes previous build artifacts
- **Package:** Compiles Java source code and creates JAR artifact
- **Output:** `target/employee-service-1.0.0.jar`
- **JDK Version:** Java 25 (Temurin)
- **Build Tool:** Apache Maven 3.9

**Dependencies:**
- Spring Boot 3.5.5
- Spring Boot Starter Web
- JaCoCo (Code Coverage) - v0.8.12

**Workflow File:** `.github/workflows/Build mvn image.yaml`

---

### 3. **SonarQube Check**
**Description:** Perform static code analysis and quality gate checks.

**Commands:**
```bash
# Run SonarQube scan
mvn sonar:sonar -Dsonar.token=$SONAR_TOKEN

# Quality Gate Check
# Uses sonarsource/sonarqube-quality-gate-action@master
```

**Details:**
- **SonarQube Server:** `http://3.18.194.203:9000`
- **Project Key:** `springboot-app` (from pom.xml)
- **SONAR_TOKEN:** Secret stored in GitHub
- **Timeout:** 10 minutes max for quality gate check
- **Purpose:** 
  - Detect bugs, vulnerabilities, and code smells
  - Measure code coverage (via JaCoCo)
  - Enforce quality standards
  - Build fails if quality gate doesn't pass

**Metrics Analyzed:**
- Code coverage
- Duplicate code
- Code complexity
- Security vulnerabilities
- Code smells

---

### 4. **Docker Image**
**Description:** Build a Docker container image for the application.

**Command:**
```bash
docker build -t employee-app:latest -f Docker .
```

**Dockerfile Details:**
The Dockerfile uses multi-stage builds for optimization:

**Build Stage:**
```dockerfile
FROM maven:3.9-eclipse-temurin-25 AS builder
WORKDIR /spring-boot-app
COPY pom.xml .
COPY src ./src
RUN mvn -B clean package
```

**Runtime Stage:**
```dockerfile
FROM eclipse-temurin:25-jre
WORKDIR /spring-boot-app
COPY --from=builder /spring-boot-app/target/*.jar employee-service.jar
EXPOSE 3006
ENTRYPOINT ["java","-jar","employee-service.jar"]
```

**Image Details:**
- **Base Image:** Eclipse Temurin JRE 25 (lightweight)
- **Application Name:** `employee-service.jar`
- **Port Exposed:** 3006 (Updated from port 80 as of 2026-08-26)
- **Image Name:** `employee-app:latest`

**Benefits:**
- Multi-stage build reduces final image size
- Only runtime dependencies in final image
- Build dependencies not included in production image

---

### 5. **Push to ECR (Elastic Container Registry)**
**Description:** Tag and push the Docker image to AWS ECR.

**Commands:**
```bash
# Tag image for ECR
docker tag employee-app:latest 675344694125.dkr.ecr.us-east-2.amazonaws.com/employee-app:latest

# Push image to ECR
docker push 675344694125.dkr.ecr.us-east-2.amazonaws.com/employee-app:latest
```

**AWS Details:**
- **AWS Account ID:** 675344694125
- **AWS Region:** us-east-2
- **ECR Repository:** employee-app
- **Authentication:** Uses AWS credentials from GitHub Secrets

**Prerequisites:**
- AWS Access Key ID (stored as `AWS_ACCESS_KEY_ID` secret)
- AWS Secret Access Key (stored as `AWS_SECRET_ACCESS_KEY` secret)
- ECR repository must exist

**Steps:**
1. Configure AWS credentials using aws-actions/configure-aws-credentials
2. Login to Amazon ECR using aws-actions/amazon-ecr-login
3. Tag the local Docker image with ECR registry URI
4. Push the tagged image to ECR

---

## EKS Deployment Infrastructure

### EKS Cluster Overview
**Description:** Production-grade EKS cluster deployment using CloudFormation.

**File:** `EKS-Cloudformation.yaml`

**Cluster Configuration:**
- **Cluster Name:** my-eks-cluster
- **Kubernetes Version:** 1.31
- **AWS Region:** us-east-2
- **CIDR Block:** 10.0.0.0/16

#### VPC & Networking Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    VPC (10.0.0.0/16)                         │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Public Subnets (IGW)                       │ │
│  │  ┌──────────────────────┐  ┌──────────────────────┐   │ │
│  │  │ PublicSubnet1        │  │ PublicSubnet2        │   │ │
│  │  │ (10.0.1.0/24)        │  │ (10.0.2.0/24)        │   │ │
│  │  │ us-east-2a           │  │ us-east-2b           │   │ │
│  │  └──────────────────────┘  └──────────────────────┘   │ │
│  └────────────────────────────────────────────────────────┘ │
│                           ↓                                  │
│                    NAT Gateway                               │
│                           ↓                                  │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Private Subnets (NAT)                      │ │
│  │  ┌──────────────────────┐  ┌──────────────────────┐   │ │
│  │  │ PrivateSubnet1       │  �� PrivateSubnet2       │   │ │
│  │  │ (10.0.3.0/24)        │  │ (10.0.4.0/24)        │   │ │
│  │  │ us-east-2a           │  │ us-east-2b           │   │ │
│  │  │ EKS Nodes            │  │ EKS Nodes            │   │ │
│  │  └──────────────────────┘  └──────────────────────┘   │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

**Subnets Details:**

| Subnet | Type | CIDR | AZ | Purpose |
|--------|------|------|-----|---------|
| PublicSubnet1 | Public | 10.0.1.0/24 | us-east-2a | Load Balancer, Ingress |
| PublicSubnet2 | Public | 10.0.2.0/24 | us-east-2b | Load Balancer, Ingress |
| PrivateSubnet1 | Private | 10.0.3.0/24 | us-east-2a | EKS Worker Nodes |
| PrivateSubnet2 | Private | 10.0.4.0/24 | us-east-2b | EKS Worker Nodes |

#### EKS Node Group Configuration

**Node Group Details:**
- **Instance Type:** t3.small (2 vCPU, 2GB RAM)
- **Minimum Nodes:** 2
- **Desired Nodes:** 2
- **Maximum Nodes:** 5 (auto-scaling)
- **AMI Type:** AL2_x86_64 (Amazon Linux 2)
- **Capacity Type:** ON_DEMAND

**Node Group Setup:**
- Nodes are deployed in **private subnets** for security
- Kubernetes service CIDR: 10.100.0.0/16
- Pod CIDR: 10.1.0.0/16

#### IAM Roles & Permissions

**EKS Cluster Role:**
```
arn:aws:iam::675344694125:role/eks-node-group-role
```

**Required Permissions:**
- EKS cluster operations
- EC2 instance management
- VPC networking
- CloudWatch logging

---

## Kubernetes Manifests

### Overview
**File:** `kubernetes-manifest.yaml`

This file defines all Kubernetes resources for deploying the Spring Boot application on EKS.

### 1. PersistentVolumeClaim (PVC)
**Description:** Storage resource for application data persistence.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: springboot-app-pvc
spec:
  storageClassName: gp2
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

**Details:**
- **Storage Class:** gp2 (General Purpose, AWS EBS)
- **Size:** 10Gi
- **Access Mode:** ReadWriteOnce (single pod access)
- **Mount Path:** /data
- **Use Case:** Application data persistence

### 2. Deployment
**Description:** Kubernetes deployment with auto-scaling and health checks.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: springboot-app
  labels:
    app: springboot-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: springboot-app
  template:
    metadata:
      labels:
        app: springboot-app
    spec:
      containers:
        - name: springboot-app
          image: IMAGE_PLACEHOLDER
          ports:
            - containerPort: 8080
```

**Deployment Configuration:**

| Property | Value | Purpose |
|----------|-------|---------|
| Replicas | 2 | High availability with 2 pod instances |
| Container Port | 8080 | Application runs on 8080 inside container |
| Image | IMAGE_PLACEHOLDER | Replace with ECR image URI |

**Resource Requests & Limits:**
```yaml
resources:
  requests:
    cpu: "250m"        # Guaranteed CPU
    memory: "256Mi"    # Guaranteed Memory
  limits:
    cpu: "500m"        # Maximum CPU
    memory: "512Mi"    # Maximum Memory
```

**Health Checks:**

#### Startup Probe
```yaml
startupProbe:
  httpGet:
    path: /api/employees/health
    port: 8080
  periodSeconds: 10
  failureThreshold: 30  # 300 seconds max startup time
```
- Checks if application is ready to start
- 30 attempts × 10 seconds = 300 seconds total
- **Endpoint:** `/api/employees/health`

#### Readiness Probe
```yaml
readinessProbe:
  httpGet:
    path: /api/employees/health
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```
- Checks if pod is ready to receive traffic
- Starts checking after 10 seconds
- Runs every 10 seconds
- Failed after 3 consecutive failures

#### Liveness Probe
```yaml
livenessProbe:
  httpGet:
    path: /api/employees/health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 15
  timeoutSeconds: 5
  failureThreshold: 3
```
- Checks if application is still running
- Starts checking after 30 seconds
- Runs every 15 seconds
- Restarts pod after 3 consecutive failures

**Volume Mounts:**
```yaml
volumeMounts:
  - name: springboot-app-storage
    mountPath: /data
```

### 3. Service
**Description:** Kubernetes service for internal load balancing.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: springboot-app-service
spec:
  selector:
    app: springboot-app
  ports:
    - port: 3006
      targetPort: 8080
      protocol: TCP
  type: ClusterIP
```

**Service Configuration:**

| Property | Value | Purpose |
|----------|-------|---------|
| Type | ClusterIP | Internal cluster load balancing |
| Service Port | 3006 | External access port |
| Target Port | 8080 | Pod container port |
| Protocol | TCP | Network protocol |

**Service Routing:**
```
External (3006) → ClusterIP Service → Deployment Pods (8080)
```

### 4. Ingress
**Description:** External traffic routing to the service.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: springboot-app-ingress
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: springboot-app-service
            port:
              number: 3006
```

**Ingress Configuration:**

| Property | Value | Purpose |
|----------|-------|---------|
| Ingress Class | nginx | NGINX Ingress Controller |
| Path | / | Root path routing |
| Path Type | Prefix | Match paths starting with / |
| Backend Service | springboot-app-service | Target service |
| Backend Port | 3006 | Service port |

**Traffic Flow:**
```
Internet → NGINX Ingress → Service (3006) → Pods (8080)
```

---

## Kubernetes Deployment Guide

### Prerequisites
```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Install AWS CLI
pip install awscli

# Install NGINX Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install nginx-ingress ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace
```

### Configure kubectl
```bash
# Update kubeconfig for EKS cluster
aws eks update-kubeconfig --name my-eks-cluster --region us-east-2

# Verify cluster connection
kubectl get nodes
```

### Deploy Application

**Step 1: Update Image Placeholder**
```bash
# Replace IMAGE_PLACEHOLDER with actual ECR image
sed -i 's|IMAGE_PLACEHOLDER|675344694125.dkr.ecr.us-east-2.amazonaws.com/employee-app:latest|g' kubernetes-manifest.yaml
```

**Step 2: Create Namespace (Optional)**
```bash
kubectl create namespace spring-boot-app
```

**Step 3: Deploy Manifests**
```bash
# Deploy all resources
kubectl apply -f kubernetes-manifest.yaml

# Or deploy with namespace
kubectl apply -f kubernetes-manifest.yaml -n spring-boot-app
```

**Step 4: Verify Deployment**
```bash
# Check deployment status
kubectl get deployments
kubectl get pods
kubectl get services
kubectl get ingress

# View pod logs
kubectl logs -f deployment/springboot-app

# Describe pod for detailed info
kubectl describe pod <pod-name>
```

### Scaling & Management

**Manual Scaling:**
```bash
# Scale deployment to 3 replicas
kubectl scale deployment springboot-app --replicas=3

# Scale back to 2 replicas
kubectl scale deployment springboot-app --replicas=2
```

**Auto-Scaling (HPA):**
```bash
# Create HPA for auto-scaling based on CPU
kubectl autoscale deployment springboot-app --min=2 --max=5 --cpu-percent=70
```

**Updating Application:**
```bash
# Update container image
kubectl set image deployment/springboot-app springboot-app=675344694125.dkr.ecr.us-east-2.amazonaws.com/employee-app:v2.0

# Check rollout status
kubectl rollout status deployment/springboot-app

# Rollback if needed
kubectl rollout undo deployment/springboot-app
```

---

## ECS Task Definition (Alternative Deployment)

### Overview
**File:** `task-definition.json`

This file defines an ECS (Elastic Container Service) task for running the application on Fargate (serverless containers).

### Configuration

```json
{
  "family": "spring-boot-app",
  "cpu": "256",
  "memory": "1024",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "containerDefinitions": [
    {
      "name": "spring-boot-app",
      "image": "675344694125.dkr.ecr.us-east-2.amazonaws.com/employee-app:latest",
      "portMappings": [
        {
          "containerPort": 3006,
          "hostPort": 3006,
          "protocol": "tcp"
        }
      ],
      "essential": true
    }
  ],
  "executionRoleArn": "arn:aws:iam::675344694125:role/ecs-task-role-for-jenkins"
}
```

**Task Details:**

| Property | Value | Purpose |
|----------|-------|---------|
| Family | spring-boot-app | Task definition family name |
| CPU | 256 | CPU units (0.25 vCPU) |
| Memory | 1024 | Memory allocation in MB |
| Network Mode | awsvpc | Task networking mode |
| Launch Type | FARGATE | Serverless container execution |
| Container Port | 3006 | Port exposed by container |

**Execution Role:**
- **Role ARN:** arn:aws:iam::675344694125:role/ecs-task-role-for-jenkins
- **Permissions:** ECR pull, CloudWatch logs

**Supported Compatibilities:**
- EC2
- Fargate
- Managed Instances

---

## Additional Stages

### 6. **Deploy Artifacts to S3**
**Description:** Archive and store build artifacts in AWS S3 bucket.

**Command:**
```bash
aws s3 cp target/employee-service-1.0.0.jar s3://mvn-artifact/maven-snapshots/
```

**Details:**
- **S3 Bucket:** mvn-artifact
- **Path:** maven-snapshots/
- **Artifact:** employee-service-1.0.0.jar

---

### 7. **Cleanup**
**Description:** Remove temporary build artifacts.

**Command:**
```bash
rm -rf target
```

**Purpose:** Clean up workspace after deployment

---

## GitHub Workflows

### Workflow 1: Build and Push to ECR
**File:** `.github/workflows/Build mvn image.yaml`

**Trigger:** Manual workflow dispatch

**Runner:** ubuntu-latest

**Key Steps:**
1. Checkout source code
2. Setup JDK 25
3. Maven build & test
4. SonarQube scan
5. Quality gate check
6. Configure AWS credentials
7. Login to ECR
8. Build Docker image
9. Tag image for ECR
10. Push to ECR
11. Upload artifacts to S3
12. Cleanup target folder


---

## Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| AWS_REGION | us-east-2 | AWS deployment region |
| ECR_REPOSITORY | employee-app | ECR repository name |
| JAVA_VERSION | 25 | Java version for build |
| APPLICATION_PORT | 3006 | Spring Boot application port |
| EKS_CLUSTER | my-eks-cluster | EKS cluster name |
| CONTAINER_PORT | 8080 | Container internal port |

---

## Secrets Required

Ensure the following GitHub Secrets are configured in your repository:

1. **AWS_ACCESS_KEY_ID** - AWS access key for ECR push
2. **AWS_SECRET_ACCESS_KEY** - AWS secret key for ECR push
3. **SONAR_TOKEN** - SonarQube authentication token
4. **KUBECONFIG** (Optional) - Kubernetes configuration for EKS

---

## Application Details

- **Project Name:** Employee Service
- **Version:** 1.0.0
- **Java Version:** 25 (Temurin)
- **Spring Boot Version:** 3.5.5
- **Build Tool:** Maven 3.9
- **Application Port:** 3006 (External)
- **Container Port:** 8080 (Internal)
- **Code Coverage Tool:** JaCoCo 0.8.12
- **Repository Type:** DevOps Practice Project
- **Cloud Platform:** AWS (EKS, ECR, ECS, S3)

---

## Repository Composition

| Language | Percentage |
|----------|-----------|
| HCL | 57.3% |
| Java | 42.7% |

**Note:** HCL files are used for Terraform Infrastructure-as-Code (IaC) configuration, while Java comprises the Spring Boot application codebase.

---

## Manual Trigger Instructions

### To run the "Build mvn image" workflow:
1. Go to GitHub repository
2. Navigate to **Actions** tab
3. Select **"build image"** workflow
4. Click **"Run workflow"**
5. Choose branch (default: main)
6. Click **"Run workflow"**

### To run the "Build and Deploy to JFrog" workflow:
1. Go to GitHub repository
2. Navigate to **Actions** tab
3. Select **"Build and Deploy to JFrog"** workflow
4. Click **"Run workflow"**
5. Click **"Run workflow"**

---

## Complete Pipeline Flow Diagram

```
┌──────────────────────────────────────────────────────────┐
│              DEVELOPER COMMITS (GitHub)                  │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ▼
        ┌────────────────────┐
        │  Maven Clean Build │
        │  mvn clean package │
        └────────┬───────────┘
                 │
                 ▼
        ┌────────────────────────┐
        │   SonarQube Analysis   │
        │  mvn sonar:sonar       │
        └────────┬───────────────┘
                 │
                 ▼
        ┌────────────────────────┐
        │  Quality Gate Check    │
        │  (Pass/Fail)           │
        └────────┬───────────────┘
                 │
                 ▼
        ┌────────────────────────┐
        │  Build Docker Image    │
        │  docker build -t ...   │
        └────────┬───────────────┘
                 │
                 ▼
        ┌────────────────────────┐
        │  Push to AWS ECR       │
        │  docker push ...       │
        └────────┬───────────────┘
                 │
    ┌────────────┴────────────┐
    │                         │
    ▼                         ▼
┌──────────────────┐   ┌──────────────────┐
│ Deploy to EKS    │   │ Deploy to ECS    │
│ (Kubernetes)     │   │ (Fargate)        │
│                  │   │                  │
│ kubectl apply    │   │ ecs update-      │
│                  │   │ service          │
└────────┬─────────┘   └────────┬─────────┘
         │                      │
         ▼                      ▼
    ┌──────────────────────────────────┐
    │   Upload to S3 Bucket            │
    │   aws s3 cp ...                  │
    └──────────────────────────────────┘
```

---

## Deployment Comparison

### EKS (Kubernetes) Deployment
**Pros:**
- Container orchestration at scale
- Auto-scaling and load balancing
- Self-healing capabilities
- Multi-region/multi-AZ support
- Declarative configuration
- Health checks and probes

**Cons:**
- More complex setup
- Requires Kubernetes knowledge
- Higher operational overhead

**Best For:** Production-grade, scalable deployments

### ECS (Fargate) Deployment
**Pros:**
- Simpler to setup
- Serverless containers (no node management)
- AWS-native service
- Lower operational overhead
- Pay-per-use pricing

**Cons:**
- Less flexibility than Kubernetes
- Vendor lock-in to AWS
- Limited container orchestration features

**Best For:** Simpler deployments, rapid prototyping

---

## Troubleshooting

### Build Failures
- Check Java version: `java -version`
- Verify Maven configuration: `mvn --version`
- Clear Maven cache: `mvn clean`
- Ensure port 3006 is not already in use

### SonarQube Quality Gate Failures
- Check SonarQube dashboard: http://3.18.194.203:9000
- Review issues and vulnerabilities
- Fix code issues and re-run pipeline

### Docker Image Push Failures
- Verify AWS credentials in GitHub Secrets
- Check ECR repository exists
- Ensure AWS IAM permissions for ECR
- Verify Docker daemon is running

### EKS Deployment Failures

**Pod not starting:**
```bash
# Check pod status
kubectl describe pod <pod-name>

# View pod logs
kubectl logs <pod-name>

# Check events
kubectl get events
```

**Image pull errors:**
```bash
# Verify ECR credentials
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 675344694125.dkr.ecr.us-east-2.amazonaws.com

# Check image exists in ECR
aws ecr describe-images --repository-name employee-app --region us-east-2
```

**Node issues:**
```bash
# Check node status
kubectl get nodes
kubectl describe node <node-name>

# Check node capacity
kubectl top nodes
kubectl top pods
```

**Service/Ingress issues:**
```bash
# Check service endpoints
kubectl get endpoints springboot-app-service

# Check ingress status
kubectl describe ingress springboot-app-ingress

# Verify NGINX ingress controller
kubectl get pods -n ingress-nginx
```

### S3 Upload Failures
- Verify S3 bucket exists and is accessible
- Check AWS IAM S3 permissions
- Ensure correct artifact path
- Verify AWS credentials have write permissions

### Port Configuration Issues
- Application runs on port **3006** (external)
- Container runs on port **8080** (internal)
- Docker EXPOSE directive should be 3006
- Update firewall/security group rules if needed

---

## Best Practices

### Development
1. **Always run locally before pushing:** Test Maven build locally
2. **Code Quality:** Ensure SonarQube quality gate passes
3. **Version Management:** Use semantic versioning
4. **Testing:** Write unit and integration tests

### DevOps/Infrastructure
1. **Infrastructure as Code:** Use Terraform/CloudFormation for reproducibility
2. **Security:** 
   - Rotate secrets regularly
   - Use IAM roles instead of access keys
   - Implement network policies
   - Scan images for vulnerabilities
3. **Monitoring:** 
   - Monitor ECR repository size
   - Watch EKS cluster metrics
   - Set CloudWatch alarms
4. **Logging:**
   - Aggregate logs in CloudWatch or ELK
   - Monitor application logs in EKS (kubectl logs)
5. **Backup & Disaster Recovery:**
   - Regular EBS snapshot backups
   - Multi-AZ deployment
   - Automated backup policies

### Kubernetes Best Practices
1. **Resource Management:**
   - Always set resource requests/limits
   - Use horizontal pod autoscaling
   - Implement pod disruption budgets
2. **Health Checks:**
   - Configure startup, readiness, and liveness probes
   - Use appropriate probe intervals
3. **Security:**
   - Use network policies
   - Implement RBAC
   - Run containers as non-root
   - Use private ECR repositories
4. **Updates & Rollouts:**
   - Use rolling updates
   - Test in staging first
   - Keep canary deployments
   - Implement blue-green deployments

---

## Further Reading

- [Spring Boot Documentation](https://spring.io/projects/spring-boot)
- [Maven Documentation](https://maven.apache.org/guides/)
- [Docker Documentation](https://docs.docker.com/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [SonarQube Documentation](https://docs.sonarqube.org/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform Documentation](https://www.terraform.io/docs/)

---

