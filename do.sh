#!/usr/bin/env bash


prj=ubuntuserver-afterinstall
here=`dirname "$(readlink -f "$BASH_SOURCE")"`
publicip=$(hostname -I | awk '{print $1}')
userpat="[a-z]{3,}"
pubfilepat="($userpat)\.pub"
rollbacktout=30
iptbackupfile=/etc/iptables/rules.v4.back
screenid=iptrollback


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
  local filename

  filename=$1/.inputrc
  usernmae=$(basename $1)

  if [ -f "$filename" ]; then
    sed -i.back '/editing-mode/d' $filename
  fi
  echo "set editing-mode vi" >> ${filename}
  chown ${username}:${username} ${filename}
  
  if [ -f "$filename.back" ]; then
    chown ${username}:${username} "${filename}.back"
  fi
}


sudoer_create () {
  local username
  local keyfile
  local sshdir

  username=$1
  keyfile=$2

  echo "creating user: ${username} ..."
  adduser ${username}
  adduser ${username} sudo

  # ssh public key file
  if [ -n "${keyfile}" ]; then
    sshdir=/home/${username}/.ssh
    if [ ! -d $sshdir ]; then
      mkdir -p $sshdir
      chown -R ${username}:${username} $sshdir
      chmod -R 700 $sshdir
    fi
    cat $keyfile >> $sshdir/authorized_keys
    chown ${username}:${username} $sshdir/authorized_keys
    chmod 600 $sshdir/authorized_keys
  fi
 
  # superuser
  if [[ "${username}" =~ "${SUPERUSER}" ]]; then
    echo "${username} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${username}"
    chmod 0440 "/etc/sudoers.d/${username}"
  fi

  read -p "Do you want to enable vi editing mode for ${username}? [N/y] " 
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    inputrc_set_vimode /home/${username} 
  fi
}


sudoerkeys_createall () {
  local keyfile
  local filename
  local username

  for keyfile in ${here}/sudoers/*.pub; do 
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
    read -p "Do you want to create the ${username} user? [N/y] " 
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      sudoer_create ${username} ${keyfile}
    fi
  done
}


ipt () {
  echo "--> iptables $@"
  iptables $@ 
  return $?
}


ipt_accept () {
  ipt -C $@ -jACCEPT 2>/dev/null || ipt -A $@ -jACCEPT 
  return $?
}


ipt_accept_input () {
  ipt_accept INPUT $@
  return $?
}


ipt_accept_input_tcp () {
  ipt_accept_input -d${publicip}/32 -ptcp -mtcp --sport 1024:65535 $@
  return $?
}


bgrollbacktask_start () {
  local cmd

  cmd="sleep $1"
  cmd="${cmd} && iptables-restore < ${iptbackupfile}"
  cmd="${cmd} && iptables -P INPUT ACCEPT"
  cmd="${cmd} && echo 'Firewall rules has been rollbacked due the timeout.'"
  
  # start a screen session to ensure rollback can be applied if disconnected.
  # if no confirmation is provided by the user (or user disconnects), 
  # after a few seconds rollback is triggered.
  echo -- screen -dmS ${screenid} bash -c "${cmd}"
  screen -dmS ${screenid} bash -c "${cmd}"
}


bgrollbacktask_kill () {
  # Stop the rollback screen session
  screen -S ${screenid} -X quit
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


if [ -z "${SUPERUSER}" ]; then
  SUPERUSER="vahid"
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


# hostname
read -p "Do you want to change the hostname? [N/y] " 
if [[ $REPLY =~ ^[Yy]$ ]]; then

  while :; do
    read -p "Enter a hostname: " nhname
    [[ $nhname =~ ^[a-z][a-z0-9-_]+$ ]] && { 
      hostnamectl hostname ${nhname}
      break
    }
  
    err "Invalid hostname: $nhname"
    continue
  done
fi


# editor -- vim
read -p "Do you want to install VIM and set it as the default editor? [N/y] " 
if [[ $REPLY =~ ^[Yy]$ ]]; then
  apt-get install -y vim

  # shell default editor
  if ! grep -qr "^export EDITOR" /etc/profile.d 2>/dev/null; then
    echo 'export EDITOR=/usr/bin/vim' >> /etc/profile.d/editor.sh
  fi

  # shell vi input mode
  read -p "Do you want to enable vi editing mode for root? [N/y] " 
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    inputrc_set_vimode /root
  fi
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
  sshportmagic="# SSH port changed by $prj"
  sed -i "/^${sshportmagic}/d" /etc/ssh/sshd_config
  sed -i '/^Port/d' /etc/ssh/sshd_config
  echo -e "${sshportmagic} at $(now)" >> /etc/ssh/sshd_config
  echo "Port ${sshport}" >> /etc/ssh/sshd_config

  # update systemd ssh socket activation
  if [[ $(lsb_release -rs) == "24.04" ]]; then
    sshsocketrestart=yes
  fi
  
  sshrestart=yes
else
  sshport=$([[ $(sudo ss -lnpt | grep ssh) =~ :([0-9]{2,5}) ]] && \
    echo ${BASH_REMATCH[1]})
fi


# ssh root password login
read -p "Do you want to disable the root SSH password login? [N/y] " 
if [[ $REPLY =~ ^[Yy]$ ]]; then
  sshrootpwdmagic="# SSH root login disabled by $prj"
  sed -i "/^${sshrootpwdmagic}/d" /etc/ssh/sshd_config
  sed -i '/^PermitRootLogin/d' /etc/ssh/sshd_config
  echo -e "${sshrootpwdmagic} at $(now)" >> /etc/ssh/sshd_config
  echo "PermitRootLogin prohibit-password" >> /etc/ssh/sshd_config
  sshrestart=yes
fi


if [[ "${sshrestart}" == "yes" ]]; then
  read -p "Do you want to restart the SSH server? [N/y] " 
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [[ "${sshsocketrestart}" == "yes" ]]; then
      systemctl daemon-reload
      systemctl restart ssh.socket
    fi
    systemctl restart ssh
  fi
fi


# create administrator users based on public keys
if [ -d "${here}/sudoers" ]; then
  read -p "Do you want to create sudoers/*.pub users? [N/y] " 
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudoerkeys_createall
  fi
fi


# create another interactive administrator user
read -p "Do you want to create another sudoer? [N/y] " 
if [[ $REPLY =~ ^[Yy]$ ]]; then
  while :; do
    read -p "Enter a sudoer username: " adminuser
    [[ $adminuser =~ ^$userpat$ ]] || { 
      err "Invalid username: $adminuser"
      continue
    }

    sudoer_create ${adminuser}
    break;
  done
fi


# firewall configration0
read -p "Do you want to configure iptables? [N/y] " 
if [[ $REPLY =~ ^[Yy]$ ]]; then
  # installing required packages
  apt-get install -y iptables-persistent

  # relax before adding rules
  ipt -P INPUT ACCEPT

  # Back up current iptables configuration
  echo "Backing up current iptables rules..."
  mkdir -p /etc/iptables/
  iptables-save > ${iptbackupfile}

  echo "Applying new iptables firewall rules..."
  ipt_accept_input -m state --state RELATED,ESTABLISHED 
  ipt_accept_input -ilo -s 127.0.0.0/8 
  ipt_accept_input_tcp --dport ${sshport}
  
  # start background rollback timer task
  bgrollbacktask_start ${rollbacktout}

  # change the input chain's policy to prevent any other packet(s).
  iptables -PINPUT DROP

  # ask user for confirmation with timeout
  echo -ne "Press ENTER to ensure you have access to the server now "
  while [[ "${rollbacktout}" -gt 0 ]]; do
    echo -ne "$(printf "(%02ds)" ${rollbacktout})"
    if read -t1; then
      bgrollbacktask_kill
      iptables-save > /etc/iptables/rules.v4
      break
    fi
    echo -ne "\b\b\b\b\b"
    rollbacktout=$((rollbacktout-1))
  done
fi


echo "Server configuration has been completed successfully."
