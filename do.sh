#!/usr/bin/env bash


set -euo pipefail


if [ -f vars.sh ]; then
  source ./vars.sh
fi


if [ -z "${SSH_PORT:-}" ]; then
  echo "SSH port [Enter=1111]:"
  read input_ssh_port
  if [ -z "${input_ssh_port}" ]; then
    SSH_PORT="1111"
  else
    SSH_PORT="${input_ssh_port}"
  fi
fi


if [ -z "${PASSWORD_ROOT:-}" ]; then
  echo "Root password [Enter=rootpassword]:"
  read -sp "" input_root_pass
  echo
  if [ -z "${input_root_pass}" ]; then
    PASSWORD_ROOT="rootpassword"
  else
    PASSWORD_ROOT="${input_root_pass}"
  fi
fi


if [ -z "${ADMIN_USERS:-}" ]; then
  echo "Admin users (user:pass) [Enter=adminuser:adminpassword]:"
  read input_admin_pair
  if [ -z "${input_admin_pair}" ]; then
    ADMIN_USERS="adminuser:adminpassword"
  else
    ADMIN_USERS="${input_admin_pair}"
  fi
fi


echo "Starting system preparation..."
apt update
apt -y dist-upgrade
apt -y purge ufw
export DEBIAN_FRONTEND=noninteractive
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" \
  > debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" \
  > debconf-set-selections
apt -y install iptables-persistent vim


if ! grep -q "EDITOR=" /etc/profile.d/editor.sh 2>/dev/null; then
  echo 'export EDITOR=/usr/bin/vim' >> /etc/profile.d/editor.sh
fi


if ! grep -q "set editing-mode vi" "${HOME}/.inputrc" 2>/dev/null; then
  echo "set editing-mode vi" >> "${HOME}/.inputrc"
fi


echo "Configuring admin users..."
echo "root:${PASSWORD_ROOT}" > /tmp/passwords.txt
NOPASS_LIST="${NOPASS_ADMIN:-}"

for entry in ${ADMIN_USERS}; do
  user=$(echo "${entry}" | cut -d':' -f1)
  user_pass=$(echo "${entry}" | cut -d':' -f2)
  if [ -z "${user_passord}" ]; then
    user_pass="adminpassword"
  fi

  if ! id -u "${user}" >/dev/null 2>&1; then
    echo "Adding administrator user: ${user}"
    adduser --disabled-password --gecos "" "${user}"
    adduser "${user}" sudo
  fi

  echo "${user}:${user_password}" >> /tmp/passwords.txt


  if [ "${user}" = "root" ]; then
    home_dir="/root"
  else
    home_dir="/home/${user}"
  fi


  mkdir -p "${home_dir}/.ssh"
  if [ -f "${user}.rsa.pub" ]; then
    cp "${user}.rsa.pub" "${home_dir}/.ssh/authorized_keys"
    chown -R ${user}:${user} "${home_dir}/.ssh"
    chmod 700 "${home_dir}/.ssh"
    chmod 600 "${home_dir}/.ssh/authorized_keys"
  fi

  user_inputrc="${home_dir}/.inputrc"
  if ! grep -q "set editing-mode vi" "${user_inputrc}" 2>/dev/null; then
    echo "set editing-mode vi" >> "${user_inputrc}"
  fi

  chown ${user}:${user} "${user_inputrc}"

  if echo " ${NOPASS_LIST} " | grep -q " ${user} "; then
    SUDO_RULE="NOPASSWD:ALL"
  else
    SUDO_RULE="ALL"
  fi
  echo "${user} ALL=(ALL) ${SUDO_RULE}" > "/etc/sudoers.d/${user}"
  chmod 0440 "/etc/sudoers.d/${user}"
done


root_home="/root"
mkdir -p "${root_home}/.ssh"
if [ -f "root.rsa.pub" ]; then
  cp "root.rsa.pub" "${root_home}/.ssh/authorized_keys"
  chown -R root:root "${root_home}/.ssh"
  chmod 700 "${root_home}/.ssh"
  chmod 600 "${root_home}/.ssh/authorized_keys"
fi


echo "Changing passwords..."
chpasswd < /tmp/passwords.txt


sed -i '/^#\?Port/d' /etc/ssh/sshd_config
sed -i '/^#\?PermitRootLogin/d' /etc/ssh/sshd_config
sed -i '/ubuntuserver-afterinstall/d' /etc/ssh/sshd_config

echo "" >> /etc/ssh/sshd_config
echo "# Added by ubuntuserver-afterinstall/do.sh" >> /etc/ssh/sshd_config
echo "Port ${SSH_PORT}" >> /etc/ssh/sshd_config
echo "PermitRootLogin prohibit-password" >> /etc/ssh/sshd_config


echo "Configuring iptables firewall..."
iptables -F
iptables -X
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p tcp --dport "${SSH_PORT}" -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT


echo "Enter additional TCP ports or empty:"
read input_tcp_ports
for port in ${input_tcp_ports:-}; do
  iptables -A INPUT -p tcp --dport "${port}" -j ACCEPT
done


echo "Enter additional UDP ports or empty:"
read input_udp_ports
for port in ${input_udp_ports:-}; do
  iptables -A INPUT -p udp --dport "${port}" -j ACCEPT
done


netfilter-persistent save


echo "Restarting SSH service..."
systemctl restart sshd
echo "Server initialization completed successfully."

