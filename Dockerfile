ARG JENKINS_VERSION=2.571

FROM jenkins/jenkins:${JENKINS_VERSION}

LABEL org.opencontainers.image.title="jenkins-dood" \
      org.opencontainers.image.description="Jenkins con Docker CLI para DooD" \
      org.opencontainers.image.version="${JENKINS_VERSION}"

USER root

ARG DOCKER_CLI_VERSION=5:27.3.1-1~debian.12~bookworm

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl && \
    install -m 0755 -d /usr/share/keyrings && \
    curl -fsSLo /usr/share/keyrings/docker-archive-keyring.asc \
        https://download.docker.com/linux/debian/gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.asc] \
        https://download.docker.com/linux/debian bookworm stable" \
        > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        docker-ce-cli=${DOCKER_CLI_VERSION} && \
    rm -rf /var/lib/apt/lists/*

USER jenkins

RUN jenkins-plugin-cli --plugins \
    docker-workflow:634.vedc7242b_eda_7 \
    docker-plugin:1316.v75635a_002b_0a_

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -fsSL http://localhost:8080/login || exit 1

EXPOSE 8080 50000