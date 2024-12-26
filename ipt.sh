iptbackupfile=/etc/iptables/rules.v4.back


ipt () {
  return iptables $@ 
}


ipt_accept () {
  return ipt -C $@ -jACCEPT && ipt -A $@ -jACCEPT 
}


ipt_accept_input () {
  return ipt_accept INPUT $@
}


ipt_accept_input_tcp () {
  return ipt_accept_input -d${publicip}/32 -ptcp -mtcp --sport 1024:65535 $@
}


bgrollbacktask_start () {
  local screenid
  local cmd

  screenid=iptrollback
  cmd="sleep ${rollbacktout}"
  cmd="${cmd} && iptables-restore < ${iptbackupfile}"
  cmd="${cmd} && echo 'Firewall rules has been rollbacked due the timeout.'"

  # start a screen session to ensure rollback can be applied if disconnected.
  # if no confirmation is provided by the user (or user disconnects), 
  # after a few seconds rollback is triggered.
  screen -dmS ${screenid} bash -c "${cmd}"

  # ask user for confirmation with timeout
  echo -ne "Do you have access to the server now "
  while [[ "${rollbacktout}" -gt 0 ]]; do
    echo -ne "$(printf "(%02ds)" ${rollbacktout})? [N/y] "
    read -t1
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo "Killing rollback timer..............."
    fi
    echo -ne "\b\b\b\b\b\b\b\b\b\b\b\b\b"
    rollbacktout=$((rollbacktout-1))
  done

}
