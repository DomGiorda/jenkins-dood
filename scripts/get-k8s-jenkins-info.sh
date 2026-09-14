#!/usr/bin/env bash
# Script para extraer la información de conexión de Kubernetes (Minikube)
# necesaria para configurar la nube Kubernetes en Jenkins UI.

set -e

NAMESPACE="${1:-jenkins}"
SERVICE_ACCOUNT="${2:-jenkins-agent-sa}"
SECRET_NAME="${3:-jenkins-agent-sa-token}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "\033[36m==========================================================\033[0m"
echo -e "\033[36m Obtención de datos de Kubernetes (Minikube) para Jenkins \033[0m"
echo -e "\033[36m==========================================================\033[0m"

if ! command -v kubectl &> /dev/null; then
    echo -e "\033[31mError: kubectl no está instalado o no se encuentra en el PATH.\033[0m"
    exit 1
fi

RBAC_PATH="${SCRIPT_DIR}/../k8s/rbac.yaml"
if [ -f "$RBAC_PATH" ]; then
    echo -e "\033[33m[+] Aplicando manifiesto RBAC en Minikube...\033[0m"
    kubectl apply -f "$RBAC_PATH"
elif command -v helm &> /dev/null && [ -d "${SCRIPT_DIR}/../k8s/helm/agent-rbac" ]; then
    echo -e "\033[33m[+] Aplicando RBAC vía Helm Chart...\033[0m"
    helm upgrade --install jenkins-agent-rbac "${SCRIPT_DIR}/../k8s/helm/agent-rbac" --namespace "$NAMESPACE" --create-namespace
fi

sleep 2

K8S_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || echo "")
MINIKUBE_IP=""
if command -v minikube &> /dev/null; then
    MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "")
fi

CA_CERT=""
CA_BASE64=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.ca\.crt}' 2>/dev/null || echo "")
if [ -n "$CA_BASE64" ]; then
    CA_CERT=$(echo "$CA_BASE64" | base64 -d 2>/dev/null || echo "$CA_BASE64" | base64 --decode 2>/dev/null)
else
    CA_BASE64=$(kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' 2>/dev/null || echo "")
    if [ -n "$CA_BASE64" ]; then
        CA_CERT=$(echo "$CA_BASE64" | base64 -d 2>/dev/null || echo "$CA_BASE64" | base64 --decode 2>/dev/null)
    fi
fi

TOKEN=""
TOKEN_BASE64=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.token}' 2>/dev/null || echo "")
if [ -n "$TOKEN_BASE64" ]; then
    TOKEN=$(echo "$TOKEN_BASE64" | base64 -d 2>/dev/null || echo "$TOKEN_BASE64" | base64 --decode 2>/dev/null)
else
    TOKEN=$(kubectl create token "$SERVICE_ACCOUNT" -n "$NAMESPACE" --duration=87600h 2>/dev/null || echo "")
fi

echo -e "\n\033[32m----------------------------------------------------------\033[0m"
echo -e "\033[32m CONFIGURACIÓN PARA JENKINS (Manage Jenkins -> Clouds -> Kubernetes)\033[0m"
echo -e "\033[32m----------------------------------------------------------\033[0m"

echo -e "\n\033[33m1. Kubernetes Name:\033[0m"
echo "   kubernetes"

echo -e "\n\033[33m2. Kubernetes Namespace:\033[0m"
echo "   ${NAMESPACE}"

echo -e "\n\033[33m3. Kubernetes URL (Servidor API de Kubernetes):\033[0m"
echo "   - URL Directa: ${K8S_SERVER}"
if [ -n "$MINIKUBE_IP" ]; then
    echo "   - Desde Minikube IP: https://${MINIKUBE_IP}:8443"
fi
echo "   - Nota para Podman/Docker: Si Jenkins corre en contenedor, usa la IP del host o host.containers.internal/host.docker.internal"

echo -e "\n\033[33m4. Kubernetes Server Certificate Key (Certificado CA PEM):\033[0m"
if [ -n "$CA_CERT" ]; then
    echo "$CA_CERT"
else
    echo "   (Desmarca 'Disable https certificate check' o ingresa la CA de ~/.kube/ca.crt)"
fi

echo -e "\n\033[33m5. Credencial en Jenkins (Secret Text):\033[0m"
echo "   Crea una credencial tipo 'Secret text' en Jenkins con el siguiente Token JWT:"
echo -e "\033[90m   --------------------------------------------------------\033[0m"
echo -e "\033[36m${TOKEN}\033[0m"
echo -e "\033[90m   --------------------------------------------------------\033[0m"

echo -e "\n\033[33m6. Jenkins URL (Para los Pods agentes en Minikube):\033[0m"
echo "   - http://host.containers.internal:8080"
echo "   - http://host.docker.internal:8080"

echo -e "\n\033[33m7. Jenkins Tunnel (Puerto TCP 50000 para Inbound Agents):\033[0m"
echo "   - host.containers.internal:50000"
echo "   - host.docker.internal:50000"

echo -e "\n\033[36m==========================================================\033[0m"
