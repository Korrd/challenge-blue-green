#!/bin/bash

# 2017-03-09
# Script created by Victor Martin as part of a series intended to demonstrate 
# the blue-green (or is it A/B?, Red-Black?, Something/Else?) approach to a
# zero-downtime deployment.

# This script deploys a new version of our software to BLUE

# For more information, hit the readme.md from this repo at <repo-address-here>!

echo "Obtaining remote IP..."
export KV_IP=$(docker-machine ssh consul 'ifconfig eth1 | grep "inet addr:" | cut -d: -f2 | cut -d" " -f1')

#Connect to environment
echo "Connecting to the swarm at "$KV_IP"..."
eval $(docker-machine env -swarm master)

echo "Determining live environment..."
live=$(docker exec bg cat /var/live)

if [ "$live" = "green" ]; then
  echo "Current environment is $(tput setaf 2)"$live"$(tput sgr 0)"

  echo "$(tput setaf 1) **** WARNING: YOU ARE DEPLOYING TO THE LIVE ENVIRONMENT!!!! ****"
  read -p "Are you sure you want to continue? <y/N>$(tput sgr 0)" prompt

  if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]]; then

    echo "Deployment in progress..."
    docker-compose up -d green
    echo "Finished!"

  else
    echo "Deployment aborted!"
    exit 0
  fi


elif [ "$live" = "blue" ]; then
  echo "Current environment is $(tput setaf 4)"$live"$(tput sgr 0)"
  echo "Deploying to $(tput setaf 4)GREEN...$(tput sgr 0)"

  docker-compose up -d green

  echo "Finished!"

else
  echo "WARNING: current LIVE environment is $(tput setaf 1)UNDEFINED$(tput sgr 0). Aborted."
fi



# *** EOF ***

