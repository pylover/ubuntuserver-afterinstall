- sshport
- configure firewall



########################################################
# echo "Restarting SSH service..."
# systemctl restart sshd
# if [ -z "${SSH_PORT}" ]; then
#   echo "SSH port [Enter=1111]:"
#   read input_ssh_port
#   if [ -z "${input_ssh_port}" ]; then
#     SSH_PORT="1111"
#   else
#     SSH_PORT="${input_ssh_port}"
#   fi
# fi
# 

################################################################
# ROLLBACK_TIMER=30
# SCREEN_NAME="iptables_restore"
# SERVER_IP=$(hostname -I | awk '{print $1}')
# 
# 
# # Back up current iptables configuration
# echo "Backing up current iptables rules..."
# mkdir -p /etc/iptables/
# iptables-save > /etc/iptables/rules.v4.backup
# 
# 
# # Rollback script file
# ROLLBACK_FILE="/tmp/firewall_rollback.sh"
# echo '#!/usr/bin/env bash
# 
# echo "Applying firewall rollback..."
# iptables-restore < /etc/iptables/rules.v4.backup
# ' > ${ROLLBACK_FILE}
# chmod +x "${ROLLBACK_FILE}"
# 
# 
# # Start a screen session to ensure rollback can be applied if disconnected.
# # If no confirmation is provided by the user (or user disconnects), after $ROLLBACK_TIMER seconds rollback is triggered.
# screen -dmS ${SCREEN_NAME} bash -c "sleep ${ROLLBACK_TIMER} && bash ${ROLLBACK_FILE} && echo 'Firewall rollback applied due to timeout.'"
# 
# 
# # Apply new iptables rules
# echo "Applying new iptables firewall rules..."
# iptables -X
# iptables -P INPUT ACCEPT
# iptables -P OUTPUT ACCEPT
# iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
# iptables -A INPUT -s 127.0.0.0/8 -j ACCEPT
# iptables -A INPUT -d $SERVER_IP/32 -p tcp -m tcp --sport 1024:65535 --dport ${SSH_PORT} -j ACCEPT  # SSH access
# iptables -A INPUT -d $SERVER_IP/32 -p tcp -m tcp --sport 1024:65535 --dport 80 -j ACCEPT           # HTTP
# iptables -A INPUT -d $SERVER_IP/32 -p tcp -m tcp --sport 1024:65535 --dport 443 -j ACCEPT          # HTTPS
# iptables -P FORWARD DROP
# iptables -P INPUT DROP
# 
# 
# # Save iptables rules (temporarily, final save will be after confirmation)
# iptables-save > /etc/iptables/rules.v4
# 
# 
# # Ask user for confirmation with timeout
# echo "Do you have access to the server now (y/n)? If you do not confirm within ${ROLLBACK_TIMER} seconds, rollback will occur:"
# if ! read -t ${ROLLBACK_TIMER} user_response; then
#   user_response="n"
# fi
# 
# 
# if [[ "$user_response" == "y" ]]; then
#   echo "User confirmed access. Canceling rollback..."
#   # Stop the rollback screen session
#   screen -S ${SCREEN_NAME} -X quit &>/dev/null || true
#   # Remove rollback file
#   rm -f "${ROLLBACK_FILE}"
#   # Persist new rules
#   iptables-save > /etc/iptables/rules.v4
#   echo "Iptables rules confirmed and saved permanently."
# else
#   bash "${ROLLBACK_FILE}"
#   # Clean up rollback screen session if still running
#   screen -S ${SCREEN_NAME} -X quit &>/dev/null || true
#   err "No confirmation received. Rolling back firewall changes..."
#   exit 1
# fi
# 
# 
# # Clean up if still needed (no harm if already cleaned)
# screen -S ${SCREEN_NAME} -X quit &>/dev/null || true
# 
# 
# 
