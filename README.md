# ubuntuserver-afterinstall

Ubuntu server preparation script.


## Features
- Secure server initialization using `iptables` firewall rules.
- Flexible SSH configuration including custom ports.
- Automatic installation and configuration of `vim` as the default editor.
- Interactive prompts for any missing variables (e.g., SSH port, admin users).


## Prerequisites
- A `Debian` server.
- `bash`


## Usage

### Quick
```bash
curl "https://raw.githubusercontent.com/pylover/ubuntuserver-afterinstall/master/do.sh" | sudo sh
```

### Standard
Clone and change to the working copy directory then create a `vars.sh` file 
with your desired configurations(see `vars.sh.example`), then:

```bash
sudo ./do.sh
```
