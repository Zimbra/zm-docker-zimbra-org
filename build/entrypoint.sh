#! /bin/bash

# configure ssh
cp -R /home/build/config/DOT-ssh $HOME/.ssh/
chmod 600 $HOME/.ssh
chmod 700 $HOME/.ssh/*
eval "$(ssh-agent -s)"

# setup zm-build
mkdir -p /home/build/zm/
(cd /home/build/zm && ssh-add && git clone git@github.com:Zimbra/zm-build.git)
cp /home/build/config/config.build /home/build/zm/zm-build/config.build

# build
(cd /home/build/zm/zm-build && ./build.pl)

# update symbolic latest build symbolic link
(cd /home/build/zm/BUILDS && rm -f latest && ln -s ./`ls  -lc | tail -n1 | awk  '{print $NF}'` latest)