#!/bin/bash

#  Semaphore Setup Script with HTTPS and Nginx
#  Author: Milad Vahdatkhah
#  Date: "Thu Jul 31 10:23:00 AM UTC 2025"

# --- Distro-Aware Setup Script ---

# Ensure FQDN is passed
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

# --- System Update ---
echo "📦 Updating system..."
if [[ "$DISTRO" == "debian" ]]; then
  sudo apt update && sudo apt upgrade -y
elif [[ "$DISTRO" == "redhat" ]]; then
  sudo yum update -y
fi

# --- Install Dependencies ---
echo "🔧 Installing dependencies..."
if [[ "$DISTRO" == "debian" ]]; then
  sudo apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg
elif [[ "$DISTRO" == "redhat" ]]; then
  sudo yum install -y yum-utils device-mapper-persistent-data lvm2 curl gnupg2 epel-release
fi

# --- Docker Installation ---
echo "🐳 Setting up Docker..."
if [[ "$DISTRO" == "debian" ]]; then
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo ${UBUNTU_CODENAME:-$VERSION_CODENAME}) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
elif [[ "$DISTRO" == "redhat" ]]; then
  sudo yum install -y docker-ce docker-ce-cli containerd.io
  sudo systemctl enable --now docker
fi

echo "✅ Docker installed"

# --- Nginx Installation ---
echo "🌐 Installing Nginx..."
if [[ "$DISTRO" == "debian" ]]; then
  sudo apt install -y nginx
elif [[ "$DISTRO" == "redhat" ]]; then
  sudo yum install -y nginx
  sudo systemctl enable --now nginx
fi

# --- Certbot Installation ---
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

# --- Launch Semaphore ---
echo "🧱 Preparing Semaphore directory..."
mkdir -p ~/semaphore && cd ~/semaphore

echo "🚀 Launching Semaphore container..."
docker-compose up -d

# --- Configure Nginx Reverse Proxy ---
echo "🔧 Setting up Nginx config..."
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

echo "🔄 Reloading Nginx..."
sudo nginx -t && sudo systemctl reload nginx

echo "✅ Setup complete! Access Semaphore at: https://$FQDN"
