#!/usr/bin/env bash


set -e


ROLLBACK_TIMER=30  # Time in seconds for rollback


echo "Starting system preparation..."
# Updating and upgrading system packages
apt update
apt -y upgrade
apt install -y vim


if ! grep -q "EDITOR=" /etc/profile.d/editor.sh 2>/dev/null; then
  echo 'export EDITOR=/usr/bin/vim' >> /etc/profile.d/editor.sh
fi


if ! grep -q "set editing-mode vi" "${HOME}/.inputrc" 2>/dev/null; then
  echo "set editing-mode vi" >> "${HOME}/.inputrc"
fi


# Configuring iptables firewall with rollback mechanism
ROLLBACK_FILE="/tmp/firewall_rollback.sh"
echo "Preparing iptables firewall configuration..."
iptables-save > /etc/iptables/rules.v4.backup


iptables -F
iptables -X
iptables -P INPUT ACCEPT
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -s 127.0.0.0/8 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --sport 1025:65535 --dport "${SSH_PORT}" -j ACCEPT
iptables -A INPUT -p tcp -m tcp --sport 1024:65535 --dport 80 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --sport 1024:65535 --dport 443 -j ACCEPT


# Save rollback script
cat <<EOT > "${ROLLBACK_FILE}"
#!/usr/bin/env bash
iptables-restore < /etc/iptables/rules.v4.backup
EOT
chmod +x "${ROLLBACK_FILE}"


# Ask user for confirmation with timeout
echo "Do you have access to the server? (yes/no):"
read -t ${ROLLBACK_TIMER} user_response || user_response="no"
if [[ "$user_response" == "yes" ]]; then
  echo "User has access. Removing rollback mechanism..."
  rm -f "${ROLLBACK_FILE}"
else
  echo "No response or user indicated no access. Starting rollback mechanism..."
  bash "${ROLLBACK_FILE}" && echo "Firewall rollback applied." && exit 1
fi


# Save iptables rules permanently
iptables-save > /etc/iptables/rules.v4


echo "Server initialization completed successfully."
