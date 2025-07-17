# VM Configuration Scripts

This repository contains a collection of scripts designed to automate the configuration of virtual machines (VMs) across various cloud providers. These scripts help you set up a consistent and ready-to-use environment with minimal manual intervention.

## Purpose

Quickly bootstrap a new VM with predefined configurations for development, testing, or deployment purposes. Suitable for VMs on AWS, GCP, Azure, or any other provider.

## Features

- OS-level configuration (e.g., package installation, system settings)
- Setup of development environments (Docker, Node.js, Python, n8n, etc.)
- Security hardening (optional)
- User and SSH configuration
- Lightweight and provider-agnostic

## Usage

1. **Create a new VM** using your preferred cloud provider.
2. **SSH into the VM** once it’s running.
3. **Run the following command**:

```bash
curl -sSL https://raw.githubusercontent.com/UsuariooRoot/vm-configurations/main/setup.sh | bash
```
