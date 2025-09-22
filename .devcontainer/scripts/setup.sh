#!/usr/bin/env bash
set -euo pipefail

# Usa sudo se existir
SUDO=""
if command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

# Instalar deps necessários (curl/unzip) se faltar
if ! command -v unzip >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    $SUDO apt-get update -y
    DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y curl unzip ca-certificates
  elif command -v dnf >/dev/null 2>&1; then
    $SUDO dnf install -y curl unzip ca-certificates
  elif command -v yum >/dev/null 2>&1; then
    $SUDO yum install -y curl unzip ca-certificates
  elif command -v apk >/dev/null 2>&1; then
    $SUDO apk add --no-cache curl unzip ca-certificates
  fi
fi

# Pula se já tiver AWS CLI
if command -v aws >/dev/null 2>&1; then
  echo "[setup] AWS CLI já instalada: $(aws --version)"
  exit 0
fi

echo "[setup] Instalando AWS CLI v2..."

# Detecta arquitetura
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64)  AWS_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" ;;
  aarch64|arm64) AWS_URL="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" ;;
  *) echo "Arquitetura não suportada: $ARCH"; exit 1 ;;
esac

# Baixa, descompacta, instala
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

curl -fsSL "$AWS_URL" -o awscliv2.zip
unzip -q awscliv2.zip

# --update evita erro se algo parcial já existir
$SUDO ./aws/install --update || $SUDO ./aws/install

echo "[setup] Concluído: $(aws --version)"
