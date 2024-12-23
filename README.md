# Server Preparation Script


## Features
- Secure server initialization using `iptables` firewall rules.
- Flexible SSH configuration including custom ports.
- Automatic installation and configuration of `vim` as the default editor.
- Interactive prompts for any missing variables (e.g., SSH port, admin users).


## Prerequisites
- A `Debian` server.
- `curl`
- `git`
- `bash`


## Usage

### Using Git
```bash
git clone https://github.com/pylover/ubuntuserver-afterinstall.git
cd ubuntuserver-afterinstall/
# Update vars.sh with your desired configurations
sudo ./do.sh
```
