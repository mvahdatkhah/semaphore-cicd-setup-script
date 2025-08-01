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

# 🔤 Allowed characters — exclude '$' to avoid shell interpolation issues
excluded_chars = "'$"
chars = string.ascii_letters + string.digits + string.punctuation

print("\n🎁 Here come your secure passwords:\n")

# 🧪 Generate passwords
for i in range(count):
    password = ''.join(random.choice(chars) for _ in range(length))
    print(password)
