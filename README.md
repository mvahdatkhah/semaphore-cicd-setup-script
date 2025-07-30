⚙️ Semaphore CI/CD Setup Script

This Bash script installs `Semaphore UI` sets up Docker, Nginx, Certbot for HTTPS, and configures a reverse proxy — all in one go.
🎯 Goal: Deploy Semaphore with secure HTTPS access using Docker and Nginx.

## 📦 Features

- 🐳 Installs Docker Engine & Compose plugin
- 🌍 Installs Nginx web server
- 🔐 Requests SSL via Let's Encrypt using Certbot
- 🔐 Generates secure admin password with password_gen.py
- 🚀 Launches Semaphore UI in a Docker container
- 🔗 Sets up HTTPS reverse proxy with Nginx

### 🚀 Quick Start
```bash
# Generate a secure admin password
python3 password_gen.py

# Copy the password and run setup
chmod +x setup_semaphore.sh
./setup_semaphore.sh your.domain.com
```

✅ Replace `your.domain.com` with your actual FQDN
✅ Make sure DNS is correctly pointed to your host machine ✅ Paste the generated password into the Docker Compose section as `SEMAPHORE_ADMIN_PASSWORD`

### 🔐 password_gen.py

This lightweight script generates a cryptographically secure admin password.
```python
#!/usr/bin/env python3

import random
import string

print("🔐 Welcome to Milad’s Password Forge!")

# 💬 Ask for user input
try:
    count = int(input("🧮 How many passwords would you like to create? "))
    length = int(input("📏 Desired length of each password? "))
except ValueError:
    print("❗Oops! That wasn’t a number. Please enter valid digits.")
    exit(1)

# 🔤 Allowed characters
chars = string.ascii_letters + string.digits + string.punctuation

print("\n🎁 Here come your secure passwords:\n")

# 🧪 Generate passwords
for i in range(count):
    password = ''.join(random.choice(chars) for _ in range(length))
    print(f"🔑 [{i+1}] {password}")
```

### 📄 Using the Generated Password
Open your `docker-compose.yml` (created during the setup) and replace the placeholder:

```yaml
SEMAPHORE_ADMIN_PASSWORD: "******************************"
```
➡️ with the password generated from password_gen.py.
💡 Use the output to replace the `SEMAPHORE_ADMIN_PASSWORD` value in your `docker-compose.yml`

### 🔧 Usage
```bash
chmod +x setup_semaphore.sh
./setup_semaphore.sh your.domain.com
```

🔸 Replace your.domain.com with your actual fully-qualified domain name (FQDN).
🔸 Make sure your DNS is pointing to the server before running this script.

## 📜 What Each Step Does

1. 🧾 Checks Input — Verifies FQDN argument.
2. 🔄 Updates System — Updates apt packages.
3. 🐳 Installs Docker Dependencies — Adds required packages and keyrings.
4. 🔐 Adds Docker Repo & Key — Integrates official Docker source.
5. 🚀 Installs Docker Engine & Compose — Installs core container tools.
6. 🌐 Installs Nginx — Web server for reverse proxy.
7. 🔐 Installs Certbot — Auto-generates SSL cert via Nginx plugin.
8. 📥 Requests SSL Certificate — Retrieves cert for the provided domain.
9. 📦 Docker Compose Setup — Creates Semaphore container config.
10. 🏗️ Starts Semaphore Container — Runs Semaphore service.
11. 🧩 Adds Nginx Reverse Proxy — Secures with HTTPS and forwards to container.
12. 🔗 Enables Nginx Config — Reloads Nginx with new site setup.

## ✅ Final Touch

Make sure you:

- Replace the admin password with the output from password_gen.py
- Backup and secure credentials properly
- Restart services after editing docker-compose.yml

## ✅ After Installation

Visit your domain in the browser:
```bash
https://your.domain.com
```

Log in to Semaphore using:

- Username: admin
- Password: the one you generated 🔒

🚨 Remember to update the admin password for security!

## 🤝 Contributing
Feel free to fork the repo and submit pull requests. Suggestions, issues, and stars are welcome! 🌟