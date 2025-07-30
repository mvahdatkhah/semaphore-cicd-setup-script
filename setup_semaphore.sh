#!/bin/bash

#  Semaphore Setup Script with HTTPS and Nginx
#  Author: Milad Vahdatkhah
#  Date: "Wed Jul 30 08:27:50 AM UTC 2025"

#  Ensure FQDN is passed
if [ -z "$1" ]; then
  echo " Error: Missing domain name."
  echo " Usage: $0 <your-fqdn>"
  exit 1
fi

FQDN="$1"

echo " Updating system..."
sudo apt update && sudo apt upgrade -y || exit 1

echo " Installing Docker & Compose dependencies..."
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg || exit 1

echo " Setting up Docker GPG key securely..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg || exit 1

echo " Adding Docker repository to sources list..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo ${UBUNTU_CODENAME:-$VERSION_CODENAME}) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo " Updating apt cache..."
sudo apt update || exit 1

echo " Installing Docker Engine and Compose plugin..."
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin || exit 1

echo " Docker and Compose installed successfully!"

echo " Installing Nginx..."
sudo apt install -y nginx || exit 1

echo " Installing Certbot..."
sudo apt install -y certbot python3-certbot-nginx || exit 1

echo " Requesting SSL certificate for $FQDN..."
if ! sudo certbot --nginx -d "$FQDN"; then
  echo " Certificate generation failed! Check DNS or domain access."
  exit 1
fi

echo " Preparing Semaphore container directory..."
mkdir -p ~/semaphore && cd ~/semaphore

#  Writing docker-compose file
cat <<EOF > docker-compose.yml
---
services:
  semaphore:
    image: semaphoreui/semaphore:v2.15.0
    container_name: semaphore
    ports:
      - "3001:3000"
    environment:
      SEMAPHORE_ADMIN: admin
      SEMAPHORE_ADMIN_PASSWORD: "nb)R2kbNpU>z3CC&a]tR'T}1"
      SEMAPHORE_DB_DIALECT: bolt
    restart: unless-stopped
...
EOF

echo " Launching Semaphore container..."
docker-compose up -d || exit 1

#  Configuring Nginx reverse proxy
echo " Setting up Nginx config..."
cat <<EOF | sudo tee /etc/nginx/sites-available/semaphore
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

echo " Enabling Nginx site..."
sudo ln -sf /etc/nginx/sites-available/semaphore /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx || exit 1

echo " Setup complete! Visit https://$FQDN to access Semaphore securely "
