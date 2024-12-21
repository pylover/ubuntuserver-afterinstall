#!/usr/bin/env bash


set -e


if [ -f vars.sh ]; then
  source ./vars.sh
fi


ROLLBACK_TIMER=30
SCREEN_NAME="iptables_restore"
SERVER_IP=$(hostname -I | awk '{print $1}')


if [ -z "${SSH_PORT:-}" ]; then
  echo "SSH port [Enter=1111]:"
  read input_ssh_port
  if [ -z "${input_ssh_port}" ]; then
    SSH_PORT="1111"
  else
    SSH_PORT="${input_ssh_port}"
  fi
fi


if [ -z "${ADMIN_USERS:-}" ]; then
  echo "Admin users (user:pass) [Enter=adminuser:adminpassword]:"
  read input_admin_pair
  if [ -n "${input_admin_pair}" ]; then
    ADMIN_USERS="${input_admin_pair}"
  fi
fi


echo "Starting system preparation..."
apt update
apt -y upgrade
apt -y purge ufw
apt install -y \
  vim \
  screen


if ! grep -q "EDITOR=" /etc/profile.d/editor.sh 2>/dev/null; then
  echo 'export EDITOR=/usr/bin/vim' >> /etc/profile.d/editor.sh
fi


if ! grep -q "set editing-mode vi" "${HOME}/.inputrc" 2>/dev/null; then
  echo "set editing-mode vi" >> "${HOME}/.inputrc"
fi


echo "Configuring admin users..."
NOPASS_LIST="${NOPASS_ADMIN:-}"


for entry in ${ADMIN_USERS}; do
  user=$(echo "${entry}" | cut -d':' -f1)
  user_password=$(echo "${entry}" | cut -d':' -f2)
  if [ -z "${user_passord}" ]; then
    user_password="${user}password"
  fi

  if ! id -u "${user}" >/dev/null 2>&1; then
    echo "Adding administrator user: ${user}"
    adduser --disabled-password --gecos "" "${user}"
    adduser "${user}" sudo
  fi

  echo "${user}:${user_password}" >> /tmp/passwords.txt
  
  if echo " ${NOPASS_LIST} " | grep -q " ${user} "; then
    SUDO_RULE="NOPASSWD:ALL"
  else
    SUDO_RULE="ALL"
  fi
  echo "${user} ALL=(ALL) ${SUDO_RULE}" > "/etc/sudoers.d/${user}"
  chmod 0440 "/etc/sudoers.d/${user}"



# Back up current iptables configuration
echo "Backing up current iptables rules..."
mkdir -p /etc/iptables/
iptables-save > /etc/iptables/rules.v4.backup


# Rollback script file
ROLLBACK_FILE="/tmp/firewall_rollback.sh"
echo '#!/usr/bin/env bash

echo "Applying firewall rollback..."
iptables-restore < /etc/iptables/rules.v4.backup
' > ${ROLLBACK_FILE}
chmod +x "${ROLLBACK_FILE}"


# Start a screen session to ensure rollback can be applied if disconnected.
# If no confirmation is provided by the user (or user disconnects), after $ROLLBACK_TIMER seconds rollback is triggered.
screen -dmS ${SCREEN_NAME} bash -c "sleep ${ROLLBACK_TIMER} && bash ${ROLLBACK_FILE} && echo 'Firewall rollback applied due to timeout.'"


# Apply new iptables rules
echo "Applying new iptables firewall rules..."
iptables -X
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -s 127.0.0.0/8 -j ACCEPT
iptables -A INPUT -d $SERVER_IP/32 -p tcp -m tcp --sport 1024:65535 --dport ${SSH_PORT} -j ACCEPT  # SSH access
iptables -A INPUT -d $SERVER_IP/32 -p tcp -m tcp --sport 1024:65535 --dport 80 -j ACCEPT           # HTTP
iptables -A INPUT -d $SERVER_IP/32 -p tcp -m tcp --sport 1024:65535 --dport 443 -j ACCEPT          # HTTPS
iptables -P FORWARD DROP
iptables -P INPUT DROP


# Save iptables rules (temporarily, final save will be after confirmation)
iptables-save > /etc/iptables/rules.v4


# Ask user for confirmation with timeout
echo "Do you have access to the server now (y/n)? If you do not confirm within ${ROLLBACK_TIMER} seconds, rollback will occur:"
if ! read -t ${ROLLBACK_TIMER} user_response; then
  user_response="n"
fi


if [[ "$user_response" == "y" ]]; then
  echo "User confirmed access. Canceling rollback..."
  # Stop the rollback screen session
  screen -S ${SCREEN_NAME} -X quit &>/dev/null || true
  # Remove rollback file
  rm -f "${ROLLBACK_FILE}"
  # Persist new rules
  iptables-save > /etc/iptables/rules.v4
  echo "Iptables rules confirmed and saved permanently."
else
  echo "No confirmation received. Rolling back firewall changes..."
  bash "${ROLLBACK_FILE}"
  # Clean up rollback screen session if still running
  screen -S ${SCREEN_NAME} -X quit &>/dev/null || true
  exit 1
fi


# Clean up if still needed (no harm if already cleaned)
screen -S ${SCREEN_NAME} -X quit &>/dev/null || true


sed -i '/^#\?Port/d' /etc/ssh/sshd_config
sed -i '/^#\?PermitRootLogin/d' /etc/ssh/sshd_config
sed -i '/ubuntuserver-afterinstall/d' /etc/ssh/sshd_config
echo "" >> /etc/ssh/sshd_config
echo "# Added by ubuntuserver-afterinstall/do.sh" >> /etc/ssh/sshd_config
echo "Port ${SSH_PORT}" >> /etc/ssh/sshd_config
echo "PermitRootLogin prohibit-password" >> /etc/ssh/sshd_config


echo "Restarting SSH service..."
systemctl restart sshd


echo "Server initialization completed successfully."
