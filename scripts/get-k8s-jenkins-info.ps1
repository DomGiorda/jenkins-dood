<#
.SYNOPSIS
    Extrae la información necesaria para configurar Kubernetes Cloud en Jenkins
    cuando Jenkins se ejecuta externamente (Docker/Podman Compose) y conecta con Minikube.
#>

param (
    [string]$Namespace = "jenkins",
    [string]$ServiceAccount = "jenkins-agent-sa",
    [string]$SecretName = "jenkins-agent-sa-token"
)

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Obtencion de datos de Kubernetes (Minikube) para Jenkins " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Verificar kubectl
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: kubectl no esta instalado o no se encuentra en el PATH." -ForegroundColor Red
    exit 1
}

# Aplicar manifiesto RBAC si existe
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$rbacPath = Join-Path $scriptDir "..\k8s\rbac.yaml"

if (Test-Path $rbacPath) {
    Write-Host "[+] Aplicando manifiesto RBAC en Minikube..." -ForegroundColor Yellow
    kubectl apply -f $rbacPath
} else {
    $helmPath = Join-Path $scriptDir "..\k8s\helm\agent-rbac"
    if ((Get-Command helm -ErrorAction SilentlyContinue) -and (Test-Path $helmPath)) {
        Write-Host "[+] Aplicando RBAC via Helm Chart..." -ForegroundColor Yellow
        helm upgrade --install jenkins-agent-rbac $helmPath --namespace $Namespace --create-namespace
    }
}

Start-Sleep -Seconds 2

# 1. Obtener URL del API Server
$k8sServer = (kubectl config view --minify -o "jsonpath={.clusters[0].cluster.server}" 2>$null)
$minikubeIp = ""
if (Get-Command minikube -ErrorAction SilentlyContinue) {
    $minikubeIp = (minikube ip 2>$null)
}

# 2. Obtener Certificado CA
$caCert = ""
$caBase64 = (kubectl get secret $SecretName -n $Namespace -o "jsonpath={.data.ca\.crt}" 2>$null)
if ($caBase64) {
    try {
        $caCert = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($caBase64))
    } catch {}
}

if (-not $caCert) {
    $caBase64 = (kubectl config view --raw --minify -o "jsonpath={.clusters[0].cluster.certificate-authority-data}" 2>$null)
    if ($caBase64) {
        try {
            $caCert = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($caBase64))
        } catch {}
    }
}

# 3. Obtener Token JWT de ServiceAccount
$token = ""
$tokenBase64 = (kubectl get secret $SecretName -n $Namespace -o "jsonpath={.data.token}" 2>$null)
if ($tokenBase64) {
    try {
        $token = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($tokenBase64))
    } catch {}
}

if (-not $token) {
    $token = (kubectl create token $ServiceAccount -n $Namespace --duration=87600h 2>$null)
}

# 4. Obtener IP local del Host
$hostIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -ExpandProperty IPAddress -First 1)

Write-Host ""
Write-Host "----------------------------------------------------------" -ForegroundColor Green
Write-Host " CONFIGURACION PARA JENKINS (Manage Jenkins -> Clouds -> Kubernetes)" -ForegroundColor Green
Write-Host "----------------------------------------------------------" -ForegroundColor Green

Write-Host ""
Write-Host "1. Kubernetes Name:" -ForegroundColor Yellow
Write-Host "   kubernetes"

Write-Host ""
Write-Host "2. Kubernetes Namespace:" -ForegroundColor Yellow
Write-Host "   $Namespace"

Write-Host ""
Write-Host "3. Kubernetes URL (Servidor API de Kubernetes):" -ForegroundColor Yellow
Write-Host "   - URL Directa: $k8sServer"
if ($minikubeIp) {
    Write-Host "   - Desde Minikube IP: https://${minikubeIp}:8443"
}
Write-Host "   - Para Podman/Docker en el host: https://host.containers.internal:8443 (o https://host.docker.internal:8443)"

Write-Host ""
Write-Host "4. Kubernetes Server Certificate Key (Certificado CA PEM):" -ForegroundColor Yellow
if ($caCert) {
    Write-Host $caCert
} else {
    Write-Host "   (Desmarca 'Disable https certificate check' o ingresa la CA de ~/.kube/ca.crt)"
}

Write-Host ""
Write-Host "5. Credencial en Jenkins (Secret Text):" -ForegroundColor Yellow
Write-Host "   Crea una credencial tipo 'Secret text' en Jenkins con el siguiente Token JWT:"
Write-Host "   --------------------------------------------------------" -ForegroundColor DarkGray
if ($token) {
    Write-Host $token -ForegroundColor Cyan
} else {
    Write-Host "   (No se pudo generar/obtener el token automáticamente. Ejecuta: kubectl create token jenkins-agent-sa -n jenkins)" -ForegroundColor Red
}
Write-Host "   --------------------------------------------------------" -ForegroundColor DarkGray

Write-Host ""
Write-Host "6. Jenkins URL (Para los Pods agentes en Minikube):" -ForegroundColor Yellow
Write-Host "   - http://host.containers.internal:8080"
Write-Host "   - http://host.docker.internal:8080"
if ($hostIp) {
    Write-Host "   - http://${hostIp}:8080"
}

Write-Host ""
Write-Host "7. Jenkins Tunnel (Puerto TCP 50000 para Inbound Agents):" -ForegroundColor Yellow
Write-Host "   - host.containers.internal:50000"
Write-Host "   - host.docker.internal:50000"
if ($hostIp) {
    Write-Host "   - ${hostIp}:50000"
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
