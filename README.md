# Server Preparation Script


## Features
- Secure server initialization using `iptables` firewall rules.
- Flexible SSH configuration including custom ports.
- Automatic installation and configuration of `vim` as the default editor.
- Interactive prompts for any missing variables (e.g., SSH port, admin users).


## Prerequisites
- A Debian or Ubuntu-based Linux server.
- `curl` installed if you want to run the script directly from a URL.
- `git` installed if you want to clone the repository.
- `bin/bash` only works on `bash`


## Usage

### Using Git
```bash
git clone https://github.com/pylover/ubuntuserver-afterinstall.git
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
ADMIN_USERS="admin1 admin2"

# If you do not set ADMIN_USERS, the script prompts and defaults to "adminuser:adminpassword".

# Define which users should have NOPASSWD sudo access:
# List the usernames that should have NOPASSWD separated by spaces.
# If none are listed, no user gets NOPASSWD:
NOPASS_ADMIN="admin1 admin2"
```
