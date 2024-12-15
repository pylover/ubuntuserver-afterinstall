# Server Preparation Script

## Features
- Secure server initialization using `iptables` firewall rules.
- Automatic setup of administrative users with optional password prompts.
- Flexible SSH configuration including custom ports and authorized keys.
- Automatic installation and configuration of `vim` as the default editor.
- Non-interactive installation of `iptables-persistent` for firewall persistence.
- Interactive prompts for any missing variables (e.g., SSH port, root password, admin users).

## Prerequisites
- A Debian or Ubuntu-based Linux server.
- `curl` installed if you want to run the script directly from a URL.
- `git` installed if you want to clone the repository.

## Usage

1. One-line installation via curl  
```bash
curl -sL "https://raw.githubusercontent.com/agrinco/ubuntuserver-afterinstall/main/do.sh" | sudo bash
```
This will run the script directly, prompting you for any missing variables.

2. Using Git
```bash
git clone https://github.com/agrinco/ubuntuserver-afterinstall.git
cd ubuntuserver-afterinstall/
# Update vars.sh with your desired configurations
sudo ./do.sh
```

## Example Configuration

### vars.sh Example
```bash
#!/usr/bin/env bash


# Override SSH port if desired:
SSH_PORT=2222

# Override the root password if desired:
PASSWORD_ROOT="mysecurepassword"

# Define admin users as username:password pairs (space-separated for multiple).
# If password is omitted after ':', it defaults to "adminpassword".
# For example:
ADMIN_USERS="admin1: admin2:secretadminpass"

# If you do not set ADMIN_USERS, the script prompts and defaults to "adminuser:adminpassword".

# Define which users should have NOPASSWD sudo access:
# List the usernames that should have NOPASSWD separated by spaces.
# If none are listed, no user gets NOPASSWD:
NOPASS_ADMIN="admin1 admin2"
```
