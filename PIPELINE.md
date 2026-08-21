# Spring Boot App - CI/CD Pipeline Documentation

## Overview
This document explains the complete CI/CD pipeline for the Spring Boot Employee Service application. The pipeline automates the process from development through to deployment on AWS infrastructure.


## Application working model

<img width="1536" height="1024" alt="Designer" src="https://github.com/user-attachments/assets/7ad05d46-c53d-4d7e-be7c-afdba3ea28e9" />

## Pipeline Architecture

```
Develop → Build → SonarQube Check → Docker Image → Push to ECR → Deploy to S3
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
- **Port Exposed:** 3006
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

---

## Secrets Required

Ensure the following GitHub Secrets are configured in your repository:

1. **AWS_ACCESS_KEY_ID** - AWS access key for ECR push
2. **AWS_SECRET_ACCESS_KEY** - AWS secret key for ECR push
3. **SONAR_TOKEN** - SonarQube authentication token
4. **JFROG_USERNAME** - JFrog Artifactory username
5. **JFROG_PASSWORD** - JFrog Artifactory password

---

## Application Details

- **Project Name:** Employee Service
- **Version:** 1.0.0
- **Java Version:** 25 (Temurin)
- **Spring Boot Version:** 3.5.5
- **Build Tool:** Maven 3.9
- **Application Port:** 3006
- **Code Coverage Tool:** JaCoCo 0.8.12

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

## Pipeline Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    DEVELOPER COMMITS                         │
└────────────────┬────────────────────────────────────────────┘
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
                 ▼
        ┌────────────────────────┐
        │  Upload to S3 Bucket   │
        │  aws s3 cp ...         │
        └────────┬───────────────┘
                 │
                 ▼
        ┌────────────────────────┐
        │  Cleanup Artifacts     │
        │  rm -rf target         │
        └────────────────────────┘
```

---

## Troubleshooting

### Build Failures
- Check Java version: `java -version`
- Verify Maven configuration: `mvn --version`
- Clear Maven cache: `mvn clean`

### SonarQube Quality Gate Failures
- Check SonarQube dashboard: http://3.18.194.203:9000
- Review issues and vulnerabilities
- Fix code issues and re-run pipeline

### Docker Image Push Failures
- Verify AWS credentials in GitHub Secrets
- Check ECR repository exists
- Ensure AWS IAM permissions for ECR

### S3 Upload Failures
- Verify S3 bucket exists and is accessible
- Check AWS IAM S3 permissions
- Ensure correct artifact path

---

## Best Practices

1. **Always run locally before pushing:** Test Maven build locally
2. **Code Quality:** Ensure SonarQube quality gate passes
3. **Review Logs:** Check workflow logs for failures
4. **Version Management:** Use semantic versioning
5. **Security:** Rotate secrets regularly
6. **Monitoring:** Monitor ECR repository size

---

## Further Reading

- [Spring Boot Documentation](https://spring.io/projects/spring-boot)
- [Maven Documentation](https://maven.apache.org/guides/)
- [Docker Documentation](https://docs.docker.com/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [SonarQube Documentation](https://docs.sonarqube.org/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

---

**Last Updated:** 2026-08-21
**Repository:** harikrishnan-creator/spring-boot-app
