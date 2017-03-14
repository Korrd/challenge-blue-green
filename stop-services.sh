#!/bin/bash

# 2017-03-09
# Script created by Victor Martin as part of a series intended to demonstrate 
# the blue-green (or is it A/B?, Red-Black?, Something/Else?) approach to a
# zero-downtime deployment.


# This script STOPS the swarm

# For more information, hit the readme.md from this repo

echo "Obtaining remote IP..."
export KV_IP=$(docker-machine ssh consul 'ifconfig eth1 | grep "inet addr:" | cut -d: -f2 | cut -d" " -f1')

#Connect to environment
echo "Connecting to the swarm at "$KV_IP"..."
eval $(docker-machine env -swarm master)

echo "$(tput setaf 1) **** WARNING: YOU ARE ABOUT TO STOP THE SWARM!!!! ****"
read -p "Are you sure you want to continue? <y/N>$(tput sgr 0)" prompt

if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]]; then

  docker-compose down
  echo "Done!"

else

  echo "Aborted!"
  exit 0

fi

# *** EOF ***

