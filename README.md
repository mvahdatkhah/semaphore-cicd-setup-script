## ⚙️ Semaphore CI/CD Setup Script

This Bash script installs `Semaphore UI` sets up Docker, Nginx, Certbot for HTTPS, and configures a reverse proxy — all in one go.
🎯 Goal: Deploy Semaphore with secure HTTPS access using Docker and Nginx.

## 📦 Features

- 🐳 Installs Docker Engine & Compose plugin
- 🛢️ Deploys PostgreSQL for persistent Semaphore data
- 🌍 Installs Nginx for reverse proxy
- 🔐 Requests SSL certificates via Certbot (Let's Encrypt)
- 🔐 Automatically generates secure credentials using generate_password.py
- 🧰 Creates and runs docker-compose.yml with secure config
- 🔗 Sets up HTTPS reverse proxy with Nginx

### 🚀 Quick Start
```bash
chmod +x setup-semaphore.sh
./setup-semaphore.sh your.domain.com
```
✅ Replace `your.domain.com` with your actual FQDN 
✅ Ensure DNS is correctly pointed to your server before execution
Generated credentials will be automatically injected and securely saved inside:

```bash
~/semaphore/postgres_password.txt
~/semaphore/semaphore_admin_password.txt
```

### 🔐 Password Generator: `generate_password.py`
This Python script generates secure passwords interactively or via stdin:
```python
#!/usr/bin/env python3

import string
import random
import argparse

# Define excluded characters to avoid shell interpolation issues
EXCLUDED_CHARS = "'$`\\\""

def build_charset():
    allowed_punctuation = ''.join(c for c in string.punctuation if c not in EXCLUDED_CHARS)
    return string.ascii_letters + string.digits + allowed_punctuation

def generate_password(length):
    chars = build_charset()
    return ''.join(random.SystemRandom().choice(chars) for _ in range(length))

def main():
    parser = argparse.ArgumentParser(description="Generate a secure password.")
    parser.add_argument("-l", "--length", type=int, default=24, help="Length of the password (default: 24)")
    parser.add_argument("-e", "--env-safe", action="store_true", help="Output in .env format (e.g. PASSWORD='yourpassword')")
    args = parser.parse_args()

    password = generate_password(args.length)
    if args.env_safe:
        print(f"PASSWORD='{password}'")
    else:
        print(password)

if __name__ == "__main__":
    main()
```
In automated mode, the Bash script runs this silently to extract strong credentials for both admin and database access.

## 📄 Docker Services Overview
Here’s what your `docker-compose.yml` includes:

| Service     | Description                            |
|-------------|----------------------------------------|
| `postgres`  | postgres                               |
| `semaphore` |  Semaphore UI connected via PostgreSQL |
| `nginx`     | Reverse proxy with HTTPS via Certbot   |                  |


## 🛠 Script Workflow

1. 🧾 Validates FQDN input
2. 🧰 Detects Linux distribution
3. 📦 Updates system packages
4. 🐳 Installs Docker and Compose plugin
5. 🌐 Installs Nginx
6. 🔐 Installs Certbot
7. 📥 Requests SSL certificate from Let's Encrypt
8. 🔑 Runs `generate_password.py` to create secure credentials
9. 📄 Builds and writes `docker-compose.yml` with secrets
10. 🚀 Starts Semaphore + PostgreSQL containers
11. 🔗 Configures and reloads Nginx HTTPS proxy


## 🔍 After Installation
Visit your deployed Semaphore UI:

```bash
https://your.domain.com
```

Log in to Semaphore using:

- Username: admin
- Password: the one you generated 🔒

🚨 Remember to update the admin password for security!

## 🤝 Contributing

You're invited to fork, star, and contribute! Ideas, issues, and PRs are welcome to strengthen this setup 💪
