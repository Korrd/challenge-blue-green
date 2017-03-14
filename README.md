# Blue Green Deployment
### Demonstration of the blue-green deployment technique

----------

# Index

 - **Foreword**
 - **Introduction**
 - **Prerequisites**
 - **Associated Material**
 - **Installation and Setup of the various components**
  - _I - Docker Installation_
  - _II - Swarm Setup_
  - _III - Blue, Green and Proxy Setup_
 - **Control of the System**
  - Deployment
  - Determining the LIVE instance
  - Switching between LIVE and IDLE instances
  - Checking the health of the service
  - Stopping the swarm
  - Disposing of the swarm
  - Bibliographic Material
  - Afterthoughts

----------

## Foreword

Just over a week ago, a challenge crossed my desk. It read: _Thou shall find a way to implement thy app with no downtime nor pain for thy user, and thou shall solve it within a week!_

I thought _huh, how hard can it be?_

And as usual, when such a question is asked, Murphy came to my place to stay for a few days. Because you know, that is how these things are.

And so this odyssey began...

This repo is about the journey of a sysadmin/developer looking for a way to solve such challenge, having done this like, ZERO times in the past. 

----------

## Introduction 

After a lot of research in the subject, I came across Mr. Martin Fowler's blog. It seems he had the exact same problem I was presented with. Namely, **how to perform Continuous Delivery without having to put the site on maintenance mode, or stopping the service altogether while doing so**. 

His approach was quite simple, yet elegant:
**By having two production machines running the exact same version of our app, only one of them being live at any given moment handling all user requests and traffic while the other is idle, the new version of our app could be deployed to the idle machine**, which is accessible on a different address and/or port, **without interrupting the users from accessing our service.**

Whenever it was required that the new version went **LIVE**, this could be easily accomplished by just redirecting traffic from the live to the idle machine _while allowing all active requests to gracefully finish_. That way, the moment the switch is made, all new requests are handled by the now LIVE machine, while the now IDLE one is in the process of being drained.

**This is accomplished by having a proxy, which is exposed to the Internet and receives all traffic, to direct it to the appropriate machine by knowing which one is currently LIVE and which one, IDLE.**

The technique is called Blue/Green Deployment (also Red/Black or A/B), and in this article, we **are** going to implement such technique.

----------

## Prerequisites

We are going to need a machine running Linux with the following software installed:

- Docker (Version 1.10 or better)
- Docker Machine (Version 0.10 or better)
- Docker Compose (Version 1.11.1 or better)

Our machines will be DigitalOcean droplets, so you will need to have an active DigitalOcean account in order to do this.

For reference, I wrote this article and implemented this solution from my development VirtualBox VM, which runs **64-bit Ubuntu Desktop 16.04 (Xenial)**.

----------

## Associated Material

Within this repo you are going to find all the scripts required to perform the various tasks associated with the installation of the required software, implementation of our solution, and also to control it and deploy the Docker containers. These are the following:

 - **Related to Installation and Setup**
  - **_docker-engine-install.sh_** - This script installs all the prerequisites here mentioned, thus enabling us to set the swarm up.
  - **_swarm-setup.sh_** - This script sets the swarm up. 

> NOTE: The installation scripts do require root privileges in order run properly.
> 

 - **Config Files**
  - **_docker-compose.yml_** - YAML file defining services, networks and volumes for docker compose.

 - **System Control and Deployment**
  - **_deploy-blue.sh_** - Deploys the container corresponding to the BLUE instance.
  - **_deploy-green.sh_** - Same thing, but for the GREEN instance.
  - **_get-live-environment.sh_** - Connects to the swarm and returns which one is the currently LIVE machine.
  - **_healthcheck.sh_** - This one checks whether our services are working, doing poorly, or not working at all. It prints their status on screen and also writes it down to a logfile located on **/var/log/challenge**. The first time it runs, it may ask for your password in order to create it and give it the right permissions.
  - **_switch-blue.sh_** - Forces the proxy to set the live environment to BLUE.
  - **_switch-green.sh_** - Same, but for GREEN.
  - **_toggle-bluegreen.sh_** - Connects to the swarm and after determining the LIVE environment, toggles it.
  - **_stop-services.sh_** - Connects to the swarm and stops it.

----------

# Installation and Swarm Setup 

## I - Docker Installation

First, we are going to install docker and its associated components. For this, we will run the **_docker-engine-install.sh_** script. This script executes the following commands:

>NOTE: Remember this was made for **Ubuntu Xenial**. If you are running a different version, or not using linux altogether, this script won't work for you!

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

>NOTE: As usergoups are enumerated at login, you will need to log out and back in for this last command to take effect. There are ways to do it without re-logging, but it's dirty, so we won't go that way unless it's really necessary 

## II - Swarm Setup

Once our prerequisites and its dependencies are installed, we can proceed to set our swarm up. For this, we will run the swarm-setup.sh script. This script executes the following commands:

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


    # Print Swarm status
    eval $(docker-machine env -swarm master)
    docker-machine ls



## III - Blue, Green and Proxy Setup

With our swarm almost ready to go, we now need to provide it with our app and proxy containers.

As the consul machine is already done, we will proceed with the Master and Slave nodes.

### The Master Node 

- **GitHub source repo** - https://github.com/Korrd/challenge-img-bluegreen
- **Docker hub image** - https://hub.docker.com/r/korrd2/blue-green/

The master node is just an nginx proxy that handles traffic redirection and switching logic. More info about it can be found on its associated GitHub repository.

We have used the registrator image to register our running docker images to consul. Consul-template will read these and create custom configuration for nginx. So we need to create a template for it, which we will call default.ctmpl and can be found

### The Slave Node

 - **GitHub source repo** - https://github.com/Korrd/challenge-bg-scroll
 - **Docker hub image** - https://hub.docker.com/r/korrd2/challenge-bg-scroll/

This is the Dockerization of a **node.js app** that demonstrates how to keep a viewport scrollbar position synchronized across all users currently viewing it by using **socket.io**. Whenever someone vertically scrolls the document, all other users get theirs scrolled to that position too. Also, whenever a new user joins, his viewport is synced to its last known position by the server.
More info regarding this app, and a walkthrough, can be read on its GitHub repository.

### Our Docker Compose File

Time to write our docker compose file, where we specify our services, networks, images, containers, and everything we require to set our site up.


    version: '2'

    services:
      bg:
        image: korrd2/blue-green:0.0.1
        container_name: bg
        ports:
          - "80:80"
          - "8080:8080"
        environment:
          - constraint:node==master
          - CONSUL_URL=${KV_IP}:8500
          - BLUE_NAME=blue
          - GREEN_NAME=green
          - LIVE=blue
        depends_on:
          - green
          - blue
        networks:
          - blue-green

      blue:
        image: korrd2/challenge-bg-scroll:1.0.1
        ports:
          - "80"
        environment:
          - SERVICE_80_NAME=blue
        networks:
          - blue-green

      green:
        image: korrd2/challenge-bg-scroll:1.0.1
        ports:
          - "80"
        environment:
          - SERVICE_80_NAME=green
        networks:
          - blue-green

    networks:
      blue-green:
        driver: overlay
    
----------

# Control of the System

Once up and running, controlling our system is quite easy. Scripts are provided by this solution that take care of it with a single command. I am going to enumerate and explain them one by one.

### Deployment

In order to deploy an app, all we have to do is to edit the _image_ section from one of the services on the _docker-compose.yml_ file (either blue or green, not bg, the proxy). After that, we just run the script related to that service. 

The **deploy-blue.sh** script will perform an update of the blue service, while the **deploy-green.sh** script will do the same for the green service.

>NOTE: Both scripts will first check whether you are deploying to the LIVE or the IDLE instance. If deployment to the LIVE one is detected, the script will warn you and prompt you to continue, the default answer being **NO**. 

### Determining the LIVE instance

In order to do so, we just run the **get-live-environment.sh** script. It will connect to the swarm and return the value for the LIVE instance. 

>NOTE: If the instance is undefined, it will issue a warning.

### Switching between LIVE and IDLE instances

There are two scripts that can do that for you. These are **switch-blue.sh** and **switch-green.sh**. Those will Force the proxy to set the live environment to their respective instances.

Also, there is a script that will automatically toggle the instances. It is called **toggle-bluegreen.sh**, and will connect to the swarm, determine which one is the LIVE instance, then switch them. 

>NOTE: If the instance is undefined, it will issue a warning.

### Checking the health of the service

For this, we have the **healthcheck.sh** script. It checks whether our services are working, doing poorly, or not working at all. It prints their status on screen and also writes it down to a logfile located on **/var/log/challenge**. 

>NOTE: This health check is quite rudimentary, and was written only for the purpose of demonstrating how to check our services are working. It will fail should the internet connection between you and the host were interrupted. Response time can also be affected by your network traffic.


>A more robust check would involve a series of services running on each container, proxy, and outside our swarm. 


> - The one running on the container would send an all-is-well signal at an interval either to a #Slack channel, email account or destination of your choice. Call it a dead-man switch. Whenever the signal stops coming, we know there is a problem with that container.
> - The one running on the proxy would check whether BLUE and GREEN are responding, and report any failure to one of the channels. It too should also send its own all-is-well signal so we know if it dies. 
> - The one running outside the cluster would check against it and inform us in case of a timeout. (This one would be similar to our current script).

> That way, we can be sure that

> - a) Whenever we have a failure anywhere on our swarm, it would let us know.
> - b) If one of the health check services were to fail, the all-is-well signal would stop, hence it would not fail silently (like what happened to the people at GitLab with their backup system). 
 

### Stopping the swarm

The **stop-services.sh** script takes care of that. It connects to the swarm and stops it all. It will prompt you before running, just in case 
it got run accidentally.

### Disposing of the swarm

I wrote no script for such action, but it can be done after stopping the swarm by executing the following commands:

    docker-machine stop consul master slave
    docker-machine rm consul master slave

----------

## Bibliographic Material

**I got the idea of using the Blue/Green technique by reading the following articles**

 - _BlueGreenDeployment, Martin Fowler_ - https://martinfowler.com/bliki/BlueGreenDeployment.html
 - _Using Blue-Green Deployment to Reduce Downtime and Risk_ - https://docs.cloudfoundry.org/devguide/deploy-apps/blue-green.html

**Regarding Docker, I read the following articles**

 - _Best practices for writing Dockerfiles_ - https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/
 - _Installing Docker Machine_ - https://docs.docker.com/machine/install-machine/#installing-machine-directly

**Also, articles related to various things**

- _Reload a Linux users-group assignments without logging out_ - https://superuser.com/questions/272061/reload-a-linux-users-group-assignments-without-logging-out

- _GitLab postmortem, or as I like to call it: "Criminal Negligence: how all went to hell because we didn't check that our backup mechanisms were working properly, nor we cared to run a simulacrum of our disaster recovery procedure in order to determine if it did work as intended"_ - https://about.gitlab.com/2017/02/10/postmortem-of-database-outage-of-january-31/
