#!/bin/bash

# 2017-03-06
# Script created by Victor Martin as part of a series intended to demonstrate 
# the blue-green (or is it A/B?, Red-Black?, Something/Else?) approach to a
# zero-downtime deployment.

# This script forces the switch to the green environment.

# For more information, hit the readme.md from this repo at <repo-address-here>!

echo "Obtaining remote IP..."
KV_IP=$(docker-machine ssh consul 'ifconfig eth1 | grep "inet addr:" | cut -d: -f2 | cut -d" " -f1')

#Connect to environment

echo "Connecting to the swarm at "$KV_IP"..."
eval $(docker-machine env -swarm master)

echo "Switching to $(tput setaf 2)GREEN $(tput sgr 0)"

docker exec bg switch green


# *** EOF ***

