#!/bin/bash

# Semaphore + PostgreSQL Setup Script with HTTPS and Nginx
# Author: Milad Vahdatkhah
# Date: Fri Aug  1 08:42:47 AM UTC 2025

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

validate_input() {
  if [ -z "$1" ]; then
    echo "❌ Error: Missing domain name."
    echo "📌 Usage: $0 <your-fqdn>"
    exit 1
  fi
  FQDN="$1"
}

detect_distribution() {
  echo "🔍 Detecting distribution..."
  source /etc/os-release
  case "$ID" in
    ubuntu|debian) DISTRO="debian" ;;
    rhel|centos|fedora) DISTRO="redhat" ;;
    *) echo "❌ Unsupported distro: $ID"; exit 1 ;;
  esac
  echo "✅ Detected: $DISTRO-based system"
}

update_system() {
  echo "📦 Updating system..."
  [[ "$DISTRO" == "debian" ]] && sudo apt update && sudo apt upgrade -y
  [[ "$DISTRO" == "redhat" ]] && sudo yum update -y
}

install_dependencies() {
  echo "🔧 Installing dependencies..."
  if [[ "$DISTRO" == "debian" ]]; then
    sudo apt install -y apt-transport-https ca-certificates curl gnupg python3
  else
    sudo yum install -y yum-utils device-mapper-persistent-data lvm2 curl gnupg2 python3
  fi
}

install_docker() {
  echo "🐳 Setting up Docker..."
  if [[ "$DISTRO" == "debian" ]]; then
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo ${UBUNTU_CODENAME:-$VERSION_CODENAME}) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  else
    sudo yum install -y docker-ce docker-ce-cli containerd.io
    sudo systemctl enable --now docker
  fi
}

install_nginx() {
  echo "🌐 Installing Nginx..."
  [[ "$DISTRO" == "debian" ]] && sudo apt install -y nginx || sudo yum install -y nginx
  sudo systemctl enable --now nginx
}

install_certbot() {
  echo "🔐 Installing Certbot..."
  [[ "$DISTRO" == "debian" ]] && sudo apt install -y certbot python3-certbot-nginx || \
    sudo yum install -y certbot python3-certbot-nginx
}

request_ssl() {
  echo "🔏 Requesting SSL certificate for $FQDN..."
  sudo certbot --nginx -d "$FQDN" || {
    echo "❗ Certificate generation failed! Check DNS or domain access."
    exit 1
  }
}

generate_password() {
  python3 "$SCRIPT_DIR/generate_password.py" <<< $'1\n20' | tail -1
}

prepare_workspace() {
  echo "🧱 Preparing Semaphore workspace..."
  cd "$SCRIPT_DIR"
  POSTGRES_PASSWORD=$(generate_password)
  SEMAPHORE_PASSWORD=$(generate_password)
  echo "'$POSTGRES_PASSWORD'" > "$SCRIPT_DIR"/postgres_password.txt
  echo "'$SEMAPHORE_PASSWORD'" > "$SCRIPT_DIR"/semaphore_admin_password.txt
  chmod 600 ~/semaphore/*.txt
}

create_compose_file() {
  echo "📝 Writing docker-compose.yml..."
  cat <<EOF > docker-compose.yml
services:
  postgres:
    image: postgres:14
    container_name: semaphore-db
    environment:
      POSTGRES_USER: semaphore
      POSTGRES_PASSWORD: "${POSTGRES_PASSWORD}"
      POSTGRES_DB: semaphore
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U semaphore"]
      interval: 5s
      timeout: 3s
      retries: 5

  semaphore:
    image: semaphoreui/semaphore:v2.15.0
    container_name: semaphore
    ports:
      - "3001:3000"
    environment:
      SEMAPHORE_ADMIN: admin
      SEMAPHORE_ADMIN_PASSWORD: "${SEMAPHORE_PASSWORD}"
      SEMAPHORE_DB_DIALECT: postgres
      SEMAPHORE_DB_HOST: postgres
      SEMAPHORE_DB_PORT: 5432
      SEMAPHORE_DB_USER: semaphore
      SEMAPHORE_DB_PASS: "${POSTGRES_PASSWORD}"
      SEMAPHORE_DB: semaphore
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped

volumes:
  postgres_data:
EOF
}

launch_services() {
  echo "🧹 Removing existing Semaphore containers..."
  docker rm -f semaphore semaphore-db || echo "⚠️ Containers not found or already removed."

  echo "🚀 Launching Semaphore + PostgreSQL..."
  docker-compose down -v && docker-compose up -d || {
    echo "❌ Failed to launch services. Check docker-compose.yml."
    exit 1
  }
}

configure_nginx() {
  echo "🔧 Configuring Nginx reverse proxy with hardened HTTPS and hidden version headers..."

  # 🔐 Hide Nginx version info in error pages and response headers
  sudo sed -i '/http {/a \\tserver_tokens off;' /etc/nginx/nginx.conf

  # 🌐 Create secure reverse proxy config for Semaphore
  cat <<EOF | sudo tee /etc/nginx/conf.d/semaphore.conf
server {
    listen 80;
    server_name $FQDN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $FQDN;

    ssl_certificate /etc/letsencrypt/live/$FQDN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$FQDN/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'HIGH:!aNULL:!MD5:!RC4';
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1h;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self';" always;

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

  echo "🔄 Reloading Nginx..."
  sudo nginx -t && sudo systemctl reload nginx
}

main() {
  validate_input "$1"
  detect_distribution
  update_system
  install_dependencies
  install_docker
  install_nginx
  install_certbot
  request_ssl
  prepare_workspace
  create_compose_file
  launch_services
  configure_nginx

  echo "✅ Setup complete! Access Semaphore at: https://$FQDN"
}

main "$@"
