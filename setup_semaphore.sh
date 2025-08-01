#!/bin/bash

# Semaphore + PostgreSQL Setup Script with HTTPS and Nginx
# Author: Milad Vahdatkhah
# Date: "Thu Jul 31 10:34:13 AM UTC 2025"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Validate Input ---
if [ -z "$1" ]; then
  echo "❌ Error: Missing domain name."
  echo "📌 Usage: $0 <your-fqdn>"
  exit 1
fi

FQDN="$1"

# --- Detect Linux Distribution ---
echo "🔍 Detecting distribution..."
source /etc/os-release

if [[ "$ID" == "ubuntu" || "$ID_LIKE" == *"debian"* ]]; then
  DISTRO="debian"
elif [[ "$ID" == "rhel" || "$ID_LIKE" == *"rhel"* || "$ID" == "centos" ]]; then
  DISTRO="redhat"
else
  echo "❌ Unsupported distro: $ID"
  exit 1
fi

echo "✅ Detected: $DISTRO-based system"

# --- Update System ---
echo "📦 Updating system..."
if [[ "$DISTRO" == "debian" ]]; then
  sudo apt update && sudo apt upgrade -y
elif [[ "$DISTRO" == "redhat" ]]; then
  sudo yum update -y
fi

# --- Install Dependencies ---
echo "🔧 Installing dependencies..."
if [[ "$DISTRO" == "debian" ]]; then
  sudo apt install -y apt-transport-https ca-certificates curl gnupg python3
elif [[ "$DISTRO" == "redhat" ]]; then
  sudo yum install -y yum-utils device-mapper-persistent-data lvm2 curl gnupg2 python3
fi

# --- Install Docker ---
echo "🐳 Setting up Docker..."
if [[ "$DISTRO" == "debian" ]]; then
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo ${UBUNTU_CODENAME:-$VERSION_CODENAME}) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
elif [[ "$DISTRO" == "redhat" ]]; then
  sudo yum install -y docker-ce docker-ce-cli containerd.io
  sudo systemctl enable --now docker
fi

# --- Install Nginx ---
echo "🌐 Installing Nginx..."
if [[ "$DISTRO" == "debian" ]]; then
  sudo apt install -y nginx
elif [[ "$DISTRO" == "redhat" ]]; then
  sudo yum install -y nginx
  sudo systemctl enable --now nginx
fi

# --- Install Certbot ---
echo "🔐 Installing Certbot..."
if [[ "$DISTRO" == "debian" ]]; then
  sudo apt install -y certbot python3-certbot-nginx
elif [[ "$DISTRO" == "redhat" ]]; then
  sudo yum install -y certbot python3-certbot-nginx
fi

# --- SSL Setup ---
echo "🔏 Requesting SSL certificate for $FQDN..."
sudo certbot --nginx -d "$FQDN" || {
  echo "❗ Certificate generation failed! Check DNS or domain access."
  exit 1
}

# --- Setup Semaphore Directory ---
echo "🧱 Preparing Semaphore workspace..."
mkdir -p ~/semaphore && cd ~/semaphore

# --- Generate Passwords ---
echo "🔐 Generating PostgreSQL and Semaphore passwords..."
generate_password() {
  python3 "$SCRIPT_DIR/generate_password.py" <<< $'1\n20' | tail -1
}

POSTGRES_PASSWORD=$(generate_password)
SEMAPHORE_PASSWORD=$(generate_password)

# --- Save Passwords Securely ---
echo "$POSTGRES_PASSWORD" > ~/semaphore/postgres_password.txt
echo "$SEMAPHORE_PASSWORD" > ~/semaphore/semaphore_admin_password.txt
chmod 600 ~/semaphore/*.txt

# --- Create Docker Compose File ---
echo "📝 Writing docker-compose.yml with secure credentials..."
cat <<EOF > docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:14
    container_name: semaphore-db
    environment:
      POSTGRES_USER: semaphore
      POSTGRES_PASSWORD: "$POSTGRES_PASSWORD"
      POSTGRES_DB: semaphore
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

  semaphore:
    image: semaphoreui/semaphore:v2.15.0
    container_name: semaphore
    ports:
      - "3001:3000"
    environment:
      SEMAPHORE_ADMIN: admin
      SEMAPHORE_ADMIN_PASSWORD: "$SEMAPHORE_PASSWORD"
      SEMAPHORE_DB_DIALECT: postgres
      SEMAPHORE_DB_HOST: postgres
      SEMAPHORE_DB_PORT: 5432
      SEMAPHORE_DB_USER: semaphore
      SEMAPHORE_DB_PASS: "$POSTGRES_PASSWORD"
      SEMAPHORE_DB: semaphore
    depends_on:
      - postgres
    restart: unless-stopped

volumes:
  postgres_data:
EOF

# --- Launch Semaphore + Postgres ---
echo "🚀 Launching Semaphore + PostgreSQL..."
docker-compose up -d

# --- Configure Nginx Proxy ---
echo "🔧 Setting up Nginx reverse proxy..."
cat <<EOF | sudo tee /etc/nginx/conf.d/semaphore.conf
server {
    listen 80;
    server_name $FQDN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $FQDN;

    ssl_certificate /etc/letsencrypt/live/$FQDN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$FQDN/privkey.pem;

    location / {
        proxy_pass http://localhost:3001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

# --- Reload Nginx ---
echo "🔄 Reloading Nginx..."
sudo nginx -t && sudo systemctl reload nginx

echo "✅ Setup complete! Access Semaphore at: https://$FQDN"
