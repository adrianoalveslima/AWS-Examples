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
else

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
fi

$SUDO apt-get install tree

# https://learn.microsoft.com/en-us/powershell/scripting/install/install-ubuntu?view=powershell-7.5
$SUDO apt-get update

# Install pre-requisite packages.
$SUDO apt-get install -y wget apt-transport-https software-properties-common


# Get the version of Ubuntu
source /etc/os-release

# Download the Microsoft repository keys
wget -q https://packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb

# Register the Microsoft repository keys
$SUDO dpkg -i packages-microsoft-prod.deb

# Delete the Microsoft repository keys file
rm packages-microsoft-prod.deb

# Update the list of packages after we added packages.microsoft.com
$SUDO apt-get update

###################################
# Install PowerShell
$SUDO apt-get install -y powershell

# pwsh
# Install-Module -Name AWS.Tools.Installer

# Atualiza pacotes
$SUDO apt-get update -y

# Dependências necessárias para compilar Ruby
$SUDO apt-get install -y \
  build-essential \
  libssl-dev \
  libreadline-dev \
  zlib1g-dev \
  libyaml-dev \
  libxml2-dev \
  libxslt1-dev \
  libffi-dev \
  libgdbm-dev \
  git \
  curl \
  wget \
  tar \
  bzip2

# Instala rbenv + ruby-build
if [ ! -d "$HOME/.rbenv" ]; then
  git clone https://github.com/rbenv/rbenv.git ~/.rbenv
  cd ~/.rbenv && src/configure && make -C src
  echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
  echo 'eval "$(rbenv init - bash)"' >> ~/.bashrc
  export PATH="$HOME/.rbenv/bin:$PATH"
  eval "$(rbenv init - bash)"
fi

# Instala plugin ruby-build
if [ ! -d "$HOME/.rbenv/plugins/ruby-build" ]; then
  git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
fi

# Instala Ruby 3.2.2
rbenv install -s 3.2.2
rbenv global 3.2.2

# Instala bundler
gem install bundler

# Garante que o rbenv está atualizado
rbenv rehash

echo "Ruby versão instalada:"
ruby -v

# ==== Pré-requisitos (se ainda não tiver) ====
$SUDO apt-get update -y
$SUDO apt-get install -y --no-install-recommends \
  build-essential libssl-dev zlib1g-dev libreadline-dev libyaml-dev \
  libxml2-dev libxslt1-dev libffi-dev libgdbm-dev git curl ca-certificates

# ==== Garante que o Ruby está no PATH (ajuste se você usa rbenv/asdf) ====
if ! command -v ruby >/dev/null 2>&1; then
  echo "Ruby não encontrado no PATH. Instale o Ruby antes (ex.: rbenv/asdf)"; exit 1
fi

# ==== Instala Bundler (idempotente) ====
if ! command -v bundle >/dev/null 2>&1; then
  # Se quiser fixar versão, use: gem install bundler -v 2.5.21
  gem install bundler
fi

# ==== Configs globais do Bundler ====
# Instala gems dentro do repositório (evita depender de PATH global do SO)
bundle config set --global path 'vendor/bundle'
# Usa jobs paralelos = núm. de CPUs (melhora performance)
bundle config set --global jobs "$(nproc || echo 4)"
# Evita instalar grupos desnecessários em ambiente de produção (ajuste conforme seu caso)
# Ex.: para Codespace de dev, provavelmente você quer TUDO; se quiser pular test/doc:
# bundle config set --global without 'development test'

# Cache local do bundler (opcional, melhora re-instalações entre rebuilds do contêiner)
mkdir -p ~/.bundle/cache

# ==== Instala dependências do sistema para gems nativas comuns ====
# Nokogiri/pg/puma/etc. já cobertos pelos pacotes acima; adicione extras se precisar.

# ==== Instala as gems do projeto se houver Gemfile ====
if [ -f "Gemfile" ]; then
  echo "Gemfile encontrado, executando bundle install…"
  # Para produção: adicione --deployment --frozen se o Gemfile.lock estiver travado
  bundle install
else
  echo "Nenhum Gemfile encontrado; pulando bundle install."
fi

# ==== Verificações ====
echo "Ruby: $(ruby -v)"
echo "Bundler: $(bundle -v)"


# ===== Config =====
ZULU_BUNDLE="zulu11.68.17-ca-jdk11.0.21-linux_x64"
ZULU_TGZ="${ZULU_BUNDLE}.tar.gz"
ZULU_URL="https://cdn.azul.com/zulu/bin/${ZULU_TGZ}"
JVM_DIR="/usr/lib/jvm"
JAVA_DIR_NAME="zulu-11.68.17-jdk11.0.21"
JAVA_HOME_DIR="${JVM_DIR}/${JAVA_DIR_NAME}"

# ===== Requisitos mínimos =====
$SUDO apt-get update -y
$SUDO apt-get install -y --no-install-recommends curl tar ca-certificates

# ===== Baixa o Zulu 11.0.21 (11.68.17) se ainda não existir =====
if [ ! -d "${JAVA_HOME_DIR}" ]; then
  echo "Baixando ${ZULU_TGZ}..."
  curl -fsSL "${ZULU_URL}" -o "/tmp/${ZULU_TGZ}"

  echo "Instalando em ${JVM_DIR}..."
  $SUDO mkdir -p "${JVM_DIR}"
  $SUDO tar -xzf "/tmp/${ZULU_TGZ}" -C "${JVM_DIR}"

  # O tarball extrai como /usr/lib/jvm/zulu11.68.17-ca-jdk11.0.21-linux_x64
  # Renomeia para um path estável/curto
  if [ -d "${JVM_DIR}/${ZULU_BUNDLE}" ]; then
    $SUDO rm -rf "${JAVA_HOME_DIR}"
    $SUDO mv "${JVM_DIR}/${ZULU_BUNDLE}" "${JAVA_HOME_DIR}"
  fi

  rm -f "/tmp/${ZULU_TGZ}"
else
  echo "Diretório ${JAVA_HOME_DIR} já existe, pulando download."
fi

# ===== update-alternatives (idempotente) =====
$SUDO update-alternatives --install /usr/bin/java  java  "${JAVA_HOME_DIR}/bin/java"  300
$SUDO update-alternatives --install /usr/bin/javac javac "${JAVA_HOME_DIR}/bin/javac" 300
$SUDO update-alternatives --install /usr/bin/jar   jar   "${JAVA_HOME_DIR}/bin/jar"   300

# Garante que esta versão é a default (sem interação)
$SUDO update-alternatives --set java  "${JAVA_HOME_DIR}/bin/java"
$SUDO update-alternatives --set javac "${JAVA_HOME_DIR}/bin/javac"
$SUDO update-alternatives --set jar   "${JAVA_HOME_DIR}/bin/jar"

# ===== JAVA_HOME para shells do Codespace =====
PROFILE_D="/etc/profile.d/java-home.sh"
if ! grep -q "${JAVA_HOME_DIR}" "${PROFILE_D}" 2>/dev/null; then
  echo "Exportando JAVA_HOME em ${PROFILE_D}"
  echo "export JAVA_HOME='${JAVA_HOME_DIR}'" | sudo tee "${PROFILE_D}" >/dev/null
  echo 'export PATH="$JAVA_HOME/bin:$PATH"'   | sudo tee -a "${PROFILE_D}" >/dev/null
fi

# ===== Verificação =====
echo "java -version:"
java -version
echo "javac -version:"
javac -version