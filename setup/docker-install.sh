#!/bin/bash

# Add repository keys
apt-key adv \
--keyserver hkp://p80.pool.sks-keyservers.net:80 \
--recv-keys 58118E89F3A912897C070ADBF76221572C52609D

# Add repository
apt-add-repository 'deb https://apt.dockerproject.org/repo ubuntu-xenial main'

# Update package lists
apt-get update

# Install docker engine (will install docker too)
apt-get install -y docker-engine

# Installation of Docker Machine
curl -L https://github.com/docker/machine/releases/download/v0.10.0/docker-machine-`uname -s`-`uname -m` >/tmp/docker-machine &&
chmod +x /tmp/docker-machine &&
cp /tmp/docker-machine /usr/local/bin/docker-machine

# Appending docker to proper user group, so we can run it without sudo
usermod -aG docker $(whoami)

echo "Done. If you want to run docker without sudo, you need to log off and back in so usergroups are updated."

