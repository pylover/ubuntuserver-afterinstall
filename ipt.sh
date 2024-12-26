iptbackupfile=/etc/iptables/rules.v4.back


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
  local screenid
  local cmd

  screenid=iptrollback
  cmd="sleep $1"
  cmd="${cmd} && iptables -P INPUT ACCEPT"
  # cmd="${cmd} && iptables-restore < ${iptbackupfile}"
  cmd="${cmd} && echo 'Firewall rules has been rollbacked due the timeout.'"

  # start a screen session to ensure rollback can be applied if disconnected.
  # if no confirmation is provided by the user (or user disconnects), 
  # after a few seconds rollback is triggered.
  screen -dmS ${screenid} bash -c "${cmd}"
}
