iptbackupfile=/etc/iptables/rules.v4.back
screenid=iptrollback


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
  # screen -S ${screenid} -X quit &>/dev/null || true
}
