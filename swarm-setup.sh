#!/bin/bash

# 2017-03-09
# Script created by Victor Martin as part of a series intended to demonstrate 
# the blue-green (or is it A/B?, Red-Black?, Something/Else?) approach to a
# zero-downtime deployment.

# This script sets up the nodes required to run a containerized app on two hosts
# at a time, blue and green. The idea behind it is to be able to update our app
# without downtime, hence only one of the machines is LIVE at any given moment.

# Whenever we need to update our app, we do it on the other one, run our tests,
# and if successful, gracefully switch to it.

# As the transfer is done, we leave the previous container to drain while all new
# requests go to the newly updated container. That way users won't notice the
# switch and there will be no downtime whatsoever. 

# In case something goes south, we can rollback by simply switching to the old
# version on the old LIVE, not-yet-updated container.

# For more information, hit the readme.md from this repo at <repo-address-here>!
echo "Before continuing, you need to edit this script and replace <YOUR_TOKEN> with your digital ocean access token."
exit

# DigitalOcean variables
DIGITALOCEAN_ACCESS_TOKEN=<YOUR_TOKEN>
DIGITALOCEAN_PRIVATE_NETWORKING=true
DIGITALOCEAN_IMAGE=debian-8-x64

# Creation of consul host
docker-machine create -d digitalocean consul

# IP address of the consul host for later use
KV_IP=$(docker-machine ssh consul 'ifconfig eth1 | grep "inet addr:" | cut -d: -f2 | cut -d" " -f1')

# Consul configuration
eval $(docker-machine env consul)

docker run -d \
  -p ${KV_IP}:8500:8500 \
  -h consul \
  --restart always \
  gliderlabs/consul-server -bootstrap


# Creation of the Master Node
docker-machine create -d digitalocean --swarm --swarm-master --swarm-discovery="consul://${KV_IP}:8500" \
  --engine-opt="cluster-store=consul://${KV_IP}:8500" --engine-opt="cluster-advertise=eth1:2376" \
  master

# Master node IP for registrator
MASTER_IP=$(docker-machine ssh master 'ifconfig eth1 | grep "inet addr:" | cut -d: -f2 | cut -d" " -f1')

# Creation of the Slave Node
docker-machine create -d digitalocean --swarm --swarm-discovery="consul://${KV_IP}:8500" \
  --engine-opt="cluster-store=consul://${KV_IP}:8500" --engine-opt="cluster-advertise=eth1:2376" \
  slave

# Slave Node IP for registrator
SLAVE_IP=$(docker-machine ssh slave 'ifconfig eth1 | grep "inet addr:" | cut -d: -f2 | cut -d" " -f1')

# Master Node configuration
eval $(docker-machine env master)

docker run -d --name=registrator -h ${MASTER_IP} --volume=/var/run/docker.sock:/tmp/docker.sock \
  gliderlabs/registrator:v6 consul://${KV_IP}:8500

#Slave Node configuration
eval $(docker-machine env slave)

docker run -d --name=registrator -h ${SLAVE_IP} --volume=/var/run/docker.sock:/tmp/docker.sock \
  gliderlabs/registrator:v6 consul://${KV_IP}:8500


# Swarm status
eval $(docker-machine env -swarm master)
docker-machine ls


# *** EOF ***
