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

