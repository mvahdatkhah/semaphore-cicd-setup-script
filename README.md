⚙️ Semaphore CI/CD Setup Script

This Bash script installs `Semaphore UI` sets up Docker, Nginx, Certbot for HTTPS, and configures a reverse proxy — all in one go.
🎯 Goal: Deploy Semaphore with secure HTTPS access using Docker and Nginx.

## 📦 What It Installs

- 🐳 Docker & Docker Compose
- 🌐 Nginx web server
- 🔐 Certbot for Let's Encrypt SSL
- 🚀 Semaphore (v2.15.0) container

### 🔧 Usage
```bash
chmod +x setup_semaphore.sh
./setup_semaphore.sh your.domain.com
```

🔸 Replace your.domain.com with your actual fully-qualified domain name (FQDN).
🔸 Make sure your DNS is pointing to the server before running this script.

📜 Step-by-Step Breakdown

1. 📍 Argument Check Checks if a domain name is passed as an argument. If not, exits with usage info.
2. 🔄 System Update Updates all system packages to the latest versions.

3. 🐳 Docker Installation
- Installs prerequisites like `curl` and `gnupg`.
- Adds Docker’s GPG key and repository.
- Installs the Docker engine and Compose plugin.

4. 🌐 Nginx Installation Installs Nginx to serve the Semaphore web UI.
5. 🔐 Certbot Installation Installs Certbot to issue SSL certificates via Let's Encrypt.
6. 📥 Certificate Request Requests an HTTPS certificate for your domain using Certbot and Nginx plugin.
7. 📦 Semaphore Setup Creates a ~/semaphore directory with a docker-compose.yml to launch Semaphore.
8. 🏗️ Container Launch Uses docker-compose to start Semaphore in the background.
9. 🧩 Nginx Proxy Setup Creates a reverse proxy config with HTTP to HTTPS redirection and SSL termination.
10. 🔗 Enable & Reload Symlinks the config into Nginx and reloads the service.

### ✅ After Installation

Visit your domain in the browser:
```bash
https://your.domain.com
```

Login with:
- Username: `admin`
- Password: the one you manually set in the Docker Compose file `(SEMAPHORE_ADMIN_PASSWORD)`

🚨 Remember to update the admin password for security!

## 🤝 Contributing
Feel free to fork the repo and submit pull requests. Suggestions, issues, and stars are welcome! 🌟