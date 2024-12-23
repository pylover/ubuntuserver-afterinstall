#!/usr/bin/env bash


set -e


err () {
  echo $@ >&2
}


inputrc_set_vimode () {
  local homedir
  local filename

  homedir=$1
  filename=$homedir/.inputrc

  if [ -f "$filename" ]; then
    sed -i.back '/editing-mode/d' $filename
  fi
  echo "set editing-mode vi" >> $filename
}


# check the platform
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  echo "Platform: $OSTYPE"
elif [[ "$OSTYPE" == "freebsd"* ]]; then
  echo "Platform: $OSTYPE"
  err "I Love $OSTYPE but, $OSTYPE is not supported!"
  exit 1
else
  err "$OSTYPE is not supported!"
  exit 1
fi


# check the shell
if [ "${SHELL}" != "/bin/bash" ]; then
  err "Please run this script with /bin/bash"
  exit 1
fi


if [ -f vars.sh ]; then
  source ./vars.sh
fi


echo "Installing and removing some packages..."
read -p "Do you want to update the aptitude catalogues? [N/y] " 
if [[ $REPLY =~ '^[Yy]$' ]]; then
  apt-get update
fi


# install packages
reqs="screen"
if [ -n "${PACKAGES}" ]; then
  reqs="${reqs} ${PACKAGES}"
fi
read -p "Do you want to install ${reqs}? [N/y] " 
if [[ $REPLY =~ '^[Yy]$' ]]; then
  apt-get install -y ${reqs}
fi


# remove packages
purges="ufw"
if [ -n "${GARBAGES}" ]; then
  purges="${purges} ${GARBAGES}"
fi
read -p "Do you want to purge ${purges}? [N/y] " 
if [[ $REPLY =~ ^[Yy]$ ]]; then
  apt-get purge -y ${purges}
fi


# editor -- vim
read -p "Do you want to install VIM and set it as the default editor? [N/y] " 
if [[ $REPLY =~ ^[Yy]$ ]]; then
  usevim=yes
  apt-get install -y vim

  # shell default editor
  if ! grep -qr "^export EDITOR" /etc/profile.d 2>/dev/null; then
    echo 'export EDITOR=/usr/bin/vim' >> /etc/profile.d/editor.sh
  fi

  # shell vi input mode
  inputrc_set_vimode /root
fi


################################################################
# ROLLBACK_TIMER=30
# SCREEN_NAME="iptables_restore"
# SERVER_IP=$(hostname -I | awk '{print $1}')
# 
# 
# if [ -z "${SSH_PORT:-}" ]; then
#   echo "SSH port [Enter=1111]:"
#   read input_ssh_port
#   if [ -z "${input_ssh_port}" ]; then
#     SSH_PORT="1111"
#   else
#     SSH_PORT="${input_ssh_port}"
#   fi
# fi
# 
# 
# if [ -z "${ADMINISTRATORS:-}" ]; then
#   echo "Enter administrator(s) credentials: i.e: 'user'":
#   read input_admin_user
#   if [ -n "${input_admin_user}" ]; then
#     ADMINISTRATORS="${input_admin_user}"
#   fi
# fi
# 
# 
# 
# echo "Configuring admin users..."
# 
# 
# for user in ${ADMINISTRATORS}; do
#   read -sp "Password for ${user}: " user_password
# 
#   if ! id -u "${user}" >/dev/null 2>&1; then
#     echo "Adding administrator user: ${user}"
#     adduser --disabled-password --gecos "" "${user}"
#     adduser "${user}" sudo
#   fi
# 
#   echo "${user}:${user_password}" >> /tmp/passwords.txt
# 
#   if echo " ${SUPERUSERS} " | grep -q " ${user} "; then
#     SUDO_RULE="NOPASSWD:ALL"
#   else
#     SUDO_RULE="ALL"
#   fi
# 
#   echo "${user} ALL=(ALL) ${SUDO_RULE}" > "/etc/sudoers.d/${user}"
#   chmod 0440 "/etc/sudoers.d/${user}"
# done
# 
# 
# echo "Changing passwords..."
# chpasswd < /tmp/passwords.txt
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
# sed -i '/^#\?Port/d' /etc/ssh/sshd_config
# sed -i '/^#\?PermitRootLogin/d' /etc/ssh/sshd_config
# sed -i '/ubuntuserver-afterinstall/d' /etc/ssh/sshd_config
# echo "" >> /etc/ssh/sshd_config
# echo "# Added by ubuntuserver-afterinstall/do.sh" >> /etc/ssh/sshd_config
# echo "Port ${SSH_PORT}" >> /etc/ssh/sshd_config
# echo "PermitRootLogin prohibit-password" >> /etc/ssh/sshd_config
# 
# 
# echo "Restarting SSH service..."
# systemctl restart sshd
# 
# 
# echo "Server initialization completed successfully."
