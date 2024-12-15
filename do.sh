#!/usr/bin/env bash


echo "Starting system preparation..."
apt update
apt -y upgrade
apt -y install vim


if ! grep -q "EDITOR=" /etc/profile.d/editor.sh 2>/dev/null; then
  echo 'export EDITOR=/usr/bin/vim' >> /etc/profile.d/editor.sh
fi


if ! grep -q "set editing-mode vi" "${HOME}/.inputrc" 2>/dev/null; then
  echo "set editing-mode vi" >> "${HOME}/.inputrc"
fi


echo "Server initialization completed successfully."
