#!/bin/bash

# 2017-03-10
# Script created by Victor Martin as part of a series intended to demonstrate 
# the blue-green (or is it A/B?, Red-Black?, Something/Else?) approach to a
# zero-downtime deployment.

# This needs to be run with root privileges, so sudo it!

# ********************************** WARNING ********************************** 
# This script installs docker-engine on an Ubuntu 16.04 (xenial) machine.
# Be careful, as you will need to change the source repo if running a different
# Ubuntu version!
# *****************************************************************************

# For more information, hit the readme.md from this repo at <repo-address-here>!


# Add repo keys
apt-key adv \
	--keyserver hkp://p80.pool.sks-keyservers.net:80 \
	--recv-keys 58118E89F3A912897C070ADBF76221572C52609D

# Add repo (WARNING, INTENDED FOR Ubuntu XENIAL! Read warning on top!)
apt-add-repository 'deb https://apt.dockerproject.org/repo ubuntu-xenial main'

# Update package lists
apt-get update

# Install docker
apt-get install -y docker-engine

# Appending docker to proper user group, so we can run it without sudo
usermod -aG docker $(whoami)

# As usergoups are enumerated at login, you may need to log out and back in so
# this last command takes effect. There are ways to do it without relogging, but
# it's dirty, so we won't go that way unless it's really necessary.
# Dirty way: https://superuser.com/questions/272061/reload-a-linux-users-group-assignments-without-logging-out

# Installation of Docker Machine
curl -L https://github.com/docker/machine/releases/download/v0.10.0/docker-machine-`uname -s`-`uname -m` >/tmp/docker-machine &&
  chmod +x /tmp/docker-machine &&
  sudo cp /tmp/docker-machine /usr/local/bin/docker-machine

# *** EOF ***
