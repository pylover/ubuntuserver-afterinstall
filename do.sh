#!/usr/bin/env bash


echo "Starting system preparation..."
apt update
apt -y upgrade
apt -y install vim


if ! grep -q "EDITOR=" /etc/profile.d/editor.sh 2>/dev/null; then
  echo 'export EDITOR=/usr/bin/vim' >> /etc/profile.d/editor.sh
fi


echo "Server initialization completed successfully."

