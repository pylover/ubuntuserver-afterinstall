#!/usr/bin/env bash


tdir=$(mktemp -d)
git clone https://github.com/pylover/ubuntuserver-afterinstall.git $tdir
cd $tdir
./do.sh
