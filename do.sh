#!/usr/bin/env bash


set -e


PRJ=ubuntuserver-afterinstall
HERE=`dirname "$(readlink -f "$BASH_SOURCE")"`
userpat="[a-z]{3,}"
pubfilepat="($userpat)\.pub"

err () {
  echo $@ >&2
}


if [ "${USER}" != "root" ]; then
  err "Please run with sudo!"
  exit 1
fi


now () {
  date +'%D %T'
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


sudoer_create () {
  local username
  local keyfile
  local sshdir

  username=$1
  keyfile=$2

  echo "creating user: $username ..."
  adduser $username && \
  adduser $username sudo || {
    return 1
  }

  if [ -n "${keyfile}" ]; then
    sshdir=/home/$username/.ssh
    if [ ! -d $sshdir ]; then
      mkdir -p $sshdir
      chown -R $username:$username $sshdir
      chmod -R 700 $sshdir
    fi
    cat $keyfile >> $sshdir/authorized_keys
    chown $username:$username $sshdir/authorized_keys
    chmod 600 $sshdir/authorized_keys
  fi
}


sudoerkeys_createall () {
  local keyfile
  local filename
  local username

  for keyfile in ${HERE}/sudoers/*.pub; do 
    if [ ! -f $keyfile ]; then
      err "file does not exists: $keyfile"
      continue;
    fi
    filename=`basename $keyfile`
    [[ $filename =~ ^$pubfilepat$ ]] || {
      err "Invalid filename: $filename, ignoring."
      continue;
    }
    username="${BASH_REMATCH[1]}"
    read -p "Do you want to create the $username user? [N/y] " 
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      sudoer_create $username $keyfile
    fi
  done
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
if [[ $REPLY =~ ^[Yy]$ ]]; then
  apt-get update
fi


# install packages
reqs="screen"
if [ -n "${PACKAGES_INSTALL}" ]; then
  reqs="${reqs} ${PACKAGES_INSTALL}"
fi
read -p "Do you want to install ${reqs}? [N/y] " 
if [[ $REPLY =~ ^[Yy]$ ]]; then
  apt-get install -y ${reqs}
fi


# remove packages
purges="ufw"
if [ -n "${PACKAGES_PURGE}" ]; then
  purges="${purges} ${PACKAGES_PURGE}"
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


# ssh port
read -p "Do you want to change the SSH server's port? [N/y] " 
if [[ $REPLY =~ ^[Yy]$ ]]; then
  if [ -n "${SSH_PORT}" ]; then
    sshport=${SSH_PORT}
  else
    while :; do
      read -p "Enter a port number between 22 and 65535: " sshport
      [[ $sshport =~ ^[0-9]+$ ]] || { 
        err "Invalid SSH port: $sshport"
        continue
      }
      if ! ((sshport >= 22 && sshport <= 65535)); then
        err "SSH port out of range: $sshport, try again"
      else
        break
      fi
    done
  fi

  echo "SSH PORT: $sshport"
  sshportmagic="# SSH port changed by $PRJ"
  sed -i "/^${sshportmagic}/d" /etc/ssh/sshd_config
  sed -i '/^Port/d' /etc/ssh/sshd_config
  echo -e "${sshportmagic} at $(now)" >> /etc/ssh/sshd_config
  echo "Port ${sshport}" >> /etc/ssh/sshd_config
  sshrestart=yes
fi


# ssh root password login
read -p "Do you want to disable the root SSH password login? [N/y] " 
if [[ $REPLY =~ ^[Yy]$ ]]; then
  sshrootpwdmagic="# SSH root login disabled by $PRJ"
  sed -i "/^${sshrootpwdmagic}/d" /etc/ssh/sshd_config
  sed -i '/^PermitRootLogin/d' /etc/ssh/sshd_config
  echo -e "${sshrootpwdmagic} at $(now)" >> /etc/ssh/sshd_config
  echo "PermitRootLogin prohibit-password" >> /etc/ssh/sshd_config
  sshrestart=yes
fi


# create administrator users based on public keys
if [ -d "${HERE}/sudoers" ]; then
  read -p "Do you want to create sudoers/*.pub users? [N/y] " 
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudoerkeys_createall
  fi
fi


# create another interactive administrator user
read -p "Do you want to create one or more sudoers? [N/y] " 
if [[ $REPLY =~ ^[Yy]$ ]]; then
  while :; do
    read -p "Enter a sudoer username: " adminuser
    [[ $adminuser =~ ^$userpat$ ]] || { 
      err "Invalid username: $adminuser"
      continue
    }

    sudoer_create $adminuser
    break;
  done
fi

########################################################
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
echo "Under construction....."


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


################################################################
# ROLLBACK_TIMER=30
# SCREEN_NAME="iptables_restore"
# SERVER_IP=$(hostname -I | awk '{print $1}')
# 
# 
# 
# 
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
# 
# echo "Server initialization completed successfully."
