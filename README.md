# Jenkins Docker-Outside-of-Docker (DooD)
![Build and Publish](https://github.com/domgiorda/jenkins-dood/actions/workflows/main.yml/badge.svg)

This is a custom Jenkins Docker image configured for **Docker-Outside-of-Docker (DooD)**. It allows Jenkins to interact with the host system's Docker daemon, enabling you to build, run, and manage Docker containers from within your Jenkins pipelines without the overhead and nesting issues of Docker-in-Docker (DinD).

## Why and What is it used for?

When running Jenkins in a containerized environment, you often need to run Docker commands inside Jenkins pipelines (e.g., building application images, running tests inside containers, and pushing to registries).

There are two primary patterns:
1. **Docker-in-Docker (DinD):** Runs a complete, isolated Docker daemon inside the Jenkins container. It requires privileged mode, which poses security risks, and can lead to storage driver/caching issues.
2. **Docker-Outside-of-Docker (DooD):** Shares the host's Docker daemon by mounting `/var/run/docker.sock`. Inside the Jenkins container, we only need the Docker CLI (command-line interface) to communicate with the host daemon. This is cleaner, faster, shares the host's image cache, and is generally preferred for CI/CD environments.

This repository automates the build of the custom Jenkins image with the Docker CLI installed and pre-configured plugins (like `docker-workflow` and `docker-plugin`), publishing it directly to GitHub Container Registry (GHCR).

## Repository Structure

```text
jenkins-dood/
├── .github/
│   └── workflows/
│       └── main.yml        # CI/CD Pipeline (GitHub Actions)
├── Dockerfile              # Custom Jenkins image definition
├── docker-compose.yml      # Example deployment file for users
└── README.md               # Documentation
```

## How to Run Jenkins (DooD)

An example `docker-compose.yml` is provided to easily spin up the environment:

```yaml
services:
  jenkins:
    image: ghcr.io/domgiorda/jenkins-dood:latest
    container_name: jenkins-dood
    restart: unless-stopped
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - jenkins_data:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
    user: "root"

volumes:
  jenkins_data:
```

Start the container with:
```bash
docker compose up -d
```
