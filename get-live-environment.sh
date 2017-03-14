#!/bin/bash

# 2017-03-06
# Script created by Victor Martin as part of a series intended to demonstrate 
# the blue-green (or is it A/B?, Red-Black?, Something/Else?) approach to a
# zero-downtime deployment.

# This script returns the current live environment.

# For more information, hit the readme.md from this repo at <repo-address-here>!

echo "Obtaining remote IP..."
KV_IP=$(docker-machine ssh consul 'ifconfig eth1 | grep "inet addr:" | cut -d: -f2 | cut -d" " -f1')

#Connect to environment
echo "Connecting to the swarm at "$KV_IP"..."
eval $(docker-machine env -swarm master)

echo "Determining live environment..."
live=$(docker exec bg cat /var/live)

if [ "$live" = "blue" ]; then
  echo "Current LIVE environment is $(tput setaf 4)"$live"$(tput sgr 0)"
elif [ "$live" = "green" ]; then
  echo "Current LIVE environment is $(tput setaf 2)"$live"$(tput sgr 0)"
else
  echo "WARNING: current LIVE environment is $(tput setaf 1)UNDEFINED$(tput sgr 0)"
fi


# *** EOF ***

