ARG JENKINS_VERSION=2.581

FROM jenkins/jenkins:${JENKINS_VERSION}

LABEL org.opencontainers.image.title="jenkins-dood" \
      org.opencontainers.image.description="Jenkins con Docker CLI para DooD" \
      org.opencontainers.image.version="${JENKINS_VERSION}"

USER root

ARG DOCKER_CLI_VERSION=5:29.8.0-1~debian.13~trixie

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates=20250419 \
        curl=8.14.1-2+deb13u5 && \
    install -m 0755 -d /usr/share/keyrings && \
    curl --proto '=https' --tlsv1.2 -fsSLo /usr/share/keyrings/docker-archive-keyring.asc \
        https://download.docker.com/linux/debian/gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.asc] \
        https://download.docker.com/linux/debian trixie stable" \
        > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        "docker-ce-cli=${DOCKER_CLI_VERSION}" && \
    rm -rf /var/lib/apt/lists/*

USER jenkins

RUN jenkins-plugin-cli --plugins \
    docker-workflow:653.v2f2c08eff0ec \
    docker-plugin:1327.v9524f1ee134e

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -fsSL http://localhost:8080/login || exit 1

EXPOSE 8080 50000