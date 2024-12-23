#!/usr/bin/env bash


cd $(mktemp -d)
git clone https://github.com/pylover/ubuntuserver-afterinstall.git
cd ubuntuserver-afterinstall
./do.sh
