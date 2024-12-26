- sshport
- configure firewall



################################################################
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
