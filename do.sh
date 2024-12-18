#!/usr/bin/env bash


set -e


ROLLBACK_TIMER=30
SCREEN_NAME="iptables_restore"
SSH_PORT=22
SERVER_IP=$(hostname -I | awk '{print $1}')


echo "Starting system preparation..."
apt update
apt -y upgrade
apt install -y \
  vim \
  screen


if ! grep -q "EDITOR=" /etc/profile.d/editor.sh 2>/dev/null; then
  echo 'export EDITOR=/usr/bin/vim' >> /etc/profile.d/editor.sh
fi


if ! grep -q "set editing-mode vi" "${HOME}/.inputrc" 2>/dev/null; then
  echo "set editing-mode vi" >> "${HOME}/.inputrc"
fi


# Back up current iptables configuration
echo "Backing up current iptables rules..."
mkdir -p /etc/iptables/
iptables-save > /etc/iptables/rules.v4.backup


# Rollback script file
ROLLBACK_FILE="/tmp/firewall_rollback.sh"
cat <<EOT > "${ROLLBACK_FILE}"
#!/usr/bin/env bash
echo "Applying firewall rollback..."
iptables-restore < /etc/iptables/rules.v4.backup
EOT
chmod +x "${ROLLBACK_FILE}"


# Start a screen session to ensure rollback can be applied if disconnected.
# If no confirmation is provided by the user (or user disconnects), after $ROLLBACK_TIMER seconds rollback is triggered.
screen -dmS ${SCREEN_NAME} bash -c "sleep ${ROLLBACK_TIMER} && bash ${ROLLBACK_FILE} && echo 'Firewall rollback applied due to timeout.'"


# Apply new iptables rules
echo "Applying new iptables firewall rules..."
iptables -F
iptables -X
iptables -P INPUT ACCEPT
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -s 127.0.0.0/8 -j ACCEPT
iptables -A INPUT -d $SERVER_IP/32 -p tcp -m tcp --sport 1024:65535 --dport ${SSH_PORT} -j ACCEPT  # SSH access
iptables -A INPUT -d $SERVER_IP/32 -p tcp -m tcp --sport 1024:65535 --dport 80 -j ACCEPT           # HTTP
iptables -A INPUT -d $SERVER_IP/32 -p tcp -m tcp --sport 1024:65535 --dport 443 -j ACCEPT          # HTTPS


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


echo "Server initialization completed successfully."
