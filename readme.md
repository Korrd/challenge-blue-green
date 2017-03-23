# Blue Green Deployment with Docker Swarm
### Demonstration of the blue-green deployment technique using docker in swarm mode

----------

# Index

 - **Foreword**
 - **Introduction**
 - **Prerequisites**
 - **How does this implementation work?**
 - **Installation and swarm setup**
   - _I - Docker Installation_
   - _II - Swarm Setup_
   - _III - Services' Deployment_
 - **Control of the System**
   - Updating our app
   - Checking the health of the service
   - Determining the LIVE instance
   - Switching between LIVE and IDLE instances
   - Draining a node
   - Disposing of the services
 - **Research Material**
 - **Afterthoughts**

----------

## Foreword

Just over a week ago, a challenge crossed my desk. It read: _Thou shall find a way to implement thy app with no downtime nor pain for thy user, and thou shall solve it within a week!_

I thought _huh, how hard can it be?_

And as usual, when such a question is asked, Murphy came to my place to stay for a few days. Because you know, that is how these things are.

And so this odyssey began...

This repository is about the journey of a sysadmin/developer looking for a way to solve such challenge, having never done this before.

----------

## Introduction 

In the past, most deployment methods required the site or app to go into maintenance mode or altogether offline in order to get updated. 
This used to be inconvenient for the user, as he can't use our service during such window. 

Historically, such maintenance windows used to be performed during off-hours, but as services become more _mission-critical_ or are provided across the globe, such practices become less and less acceptable, as there are no off-hours anymore.

Also, if something went wrong, a rollback might require the old version to be re-uploaded or restored from an out-of-site backup, adding up to the total downtime and also to the unhappiness of the userbase. 

So, having considered that, I began my research into the matter, and after some time, I came across Mr. Martin Fowler's blog. It seems he has had the exact same problem I was presented with. Namely, **how to perform Continuous Delivery without having to put the site on maintenance mode, or stopping the service altogether while doing so**. 

**His approach was quite simple, yet elegant:**

>**By having two production machines running the exact same version of our app, only one of them being live at any given moment handling all user requests and traffic while the other is idle, the new version of our app could be deployed to the idle machine**, which is accessible on a different address and/or port, **without interrupting the users from accessing our service.**

>Whenever it was required that the new version went **LIVE**, this could be easily accomplished by just redirecting traffic from the live to the idle machine _while allowing all active requests to gracefully finish_. That way, the moment the switch is made, all new requests are handled by the now LIVE machine, while the now IDLE one is in the process of being drained.

The technique is called Blue/Green Deployment (also Red/Black or A/B), and in this article, we are going to implement it using **docker swarm**.

----------

## Prerequisites

In order to proceed with these instructions, you will first need to have:


### 1. Virtual Machines

**Three networked VM's**

- Manager1, our swarm controller
- Worker1, our first swarm worker
- Worker2, our second swarm worker


**The following ports must be available. On some systems, these ports are open by default**

- TCP port 2377 for cluster management communications
- TCP and UDP port 7946 for communication among nodes
- UDP port 4789 for overlay network traffic
- TCP ports 3000 and 3001 for connecting our services
- TCP ports 80 and 8080 on manager1

**The VM's require the following software installed**

- Ubuntu 16.04 xenial, 64-bit on all machines
- Docker Engine 1.12 or newer on all machines (I'm using the latest version)
- Nginx 1.10 or newer on manager1

**Also, we need to assign fixed IP addresses to those machines. In this article, I will be using 192.168.2.11 for the manager/proxy, 192.168.2.12 for the first worker and 192.168.2.13 for the second worker.**

### 2. Local machine

Our local machine will require the latest version of Docker installed, and also an ssh client of your choice. **I'm currently using vanilla Ubuntu 16.04 xenial 64bit with Docker version 17.03.0-ce**.

----------

# How does this implementation work?

**Using docker swarm**, we will create a swarm consisting of a manager and two workers. On it, we will be running two services listening on different ports. These will be our Blue and Green. Each service will be running identical versions of our app. 

The swarm will be behind an **nginx proxy** which will be exposed to the internet. This proxy will determine which service is **LIVE** and which is **IDLE**, and will route all incoming traffic on port 80 to our **LIVE** serice, and all traffic on port 8080 to the **IDLE** service.

Whenever we need to update our software, we will do so on the **IDLE** service, while leaving the **LIVE** one deal with users.

Once app testing is complete, and the newly updated version is deemed fit for production, the proxy will be commanded to graciously switch traffic from **LIVE** to **IDLE**, swapping their roles. This way, those requests that are in progress will be allowed to finish, while new requests will be directed to the **now LIVE** service without any kind of downtime, hence performing updates without downtime.


----------

# Installation and Swarm Setup 

## I - Docker Installation

First, we are going to install docker and its associated components. For this, run the **_docker-install.sh_** script (located on the setup folder) _on manager1, worker1 and worker2_. This script executes the following commands:

>NOTE: Remember this was made for **Ubuntu Xenial**. If you are running a different version on the VM's, or not using linux altogether, this script won't work for you!

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

### Proxy Setup

Connect to the Manager node by SSH, and once logged in, install nginx:

	sudo apt-get install nginx

Once installed, create a file named "/var/live" and write "blue" to it:

	echo "blue" > /var/live

Whenever we start the VM or toggle between blue and green, this will tell us which service is currently **LIVE**.
It will also be used by consul in order to write the nginx config file.


### Consul-template setup

Connect to the Manager node by SSH, and once logged in, install consul-template by running the **_consul-install.sh_** script (located on the setup folder). This script executes the following commands:

	wget https://releases.hashicorp.com/consul-template/0.18.0/consul-template_0.18.0_linux_amd64.zip
	unzip consul-template_0.18.0_linux_amd64.zip -d /usr/local/bin
	chmod +x /usr/local/bin/consul-template
    mkdir /templates

Once done, open default.ctmpl and replace the 
MANAGER-IP-ADDRESS placeholders with the IP address of your manager node, then copy this file to /templates

In order to set nginx to its initial value, run the **toggle.sh_** script with blue as a parameter. This will command consul to write the new nginx configuration, and then reload nginx so the changes take effect.


### Setting up the Manager node

Connect to the Manager node by SSH, and once logged in, run the following command:

	docker swarm init --advertise-addr <MANAGER-IP-ADDRESS>

If successfully executed, you will get the following output:

	Swarm initialized: current node () is now a manager.

	To add a worker to this swarm, run the following command:

	    docker swarm join \
	    --token <TOKEN> \
	    <MANGER-IP-ADDRESS>:2377

	To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.

Save the _first_ command for later use, as we will be using it on each of the worker nodes.

### Setting up the worker nodes

Exit the Manager, SSH into the _first_ worker node, and run the command we saved earlier:

	docker swarm join \
	--token <TOKEN> \
	<MANGER-IP-ADDRESS>:2377

>NOTE: The placeholders will instead be the token and IP address of the manager node.

After a few seconds, you will get the following message, which means the node was added to our swarm successfully:

>This node joined a swarm as a worker.

**Repeat this step on the second worker node**

### Checking the nodes status

SSH into the machine where the manager node runs and run the following command to see the worker nodes' status:

	docker node ls 

You will see output similar to the following, which means our swarm is running as expected:

	ID                           HOSTNAME  STATUS  AVAILABILITY  MANAGER STATUS
	03g1y59jwfg7cf99w4lt0f662    worker2   Ready   Active
	9j68exjopxe7wfl6yuxml7a7j    worker1   Ready   Active
	dxn1zf6l61qsb1josjja83ngz *  manager1  Ready   Active        Leader


## III - Services' Deployment

Now that our swarm is up and running, we will Deploy our services. For the pruposes of this article we will be using the following app, which can be found here:

 - **GitHub source repo** - https://github.com/Korrd/challenge-bg-scroll
 - **Docker hub image** - https://hub.docker.com/r/korrd2/challenge-bg-scroll/

SSH into the Manager node, and run the following commands:


	docker service create --workdir="/app" --publish 3000:3000 --name="blue-service" korrd2/challenge-bg-scroll:1.0.3
	docker service create --workdir="/app" --publish 3001:3000 --name="green-service" korrd2/challenge-bg-scroll:1.0.4

This will create two services, each running identical copies of our app.

Run the following command in order to see its status:

	docker service ls

You will get output similar to the following, which means our services are running as expected: 

	ID            NAME          MODE        REPLICAS  IMAGE
	6dkch7ddr3mz  scroll-green  replicated  1/1       korrd2/challenge-bg-scroll:1.0.4
	84f44rcqmaqb  scroll-blue   replicated  1/1       korrd2/challenge-bg-scroll:1.0.3



**At this point, if you navigate to http://MANGER-IP-ADDRESS or http://MANGER-IP-ADDRESS:8080, you will see both the LIVE and IDLE services up and running.**

# Control of the System

Once up and running, controlling our system is quite easy. Scripts are provided by this solution that take care of it with a single command. I am going to enumerate and explain them one by one.

## Updating our app

In order to update our app, run either **_deploy-blue.sh_** or **_deploy-green.sh_** using the image tag as parameter. 

>NOTE: Both scripts will first check whether you are deploying to the LIVE or the IDLE service. If deployment to LIVE is detected, the script will warn you and prompt you to continue, the default answer being **NO**. 


## Scaling our services

In order to scale our services run either **_scale-blue.sh_** or **_scale-green.sh_**, to change the desired state of the service running in the swarm. These scripts take a number as a parameter, which will determine its size.

Run the following command to see the updated task list:

	docker service ps <SERVICE-ID>

## Checking the health of the service

For this, we have the **healthcheck.sh** script. It checks whether our services are working, doing poorly, or not working at all. It prints their status on screen and also writes it down to a logfile located on **/var/log/challenge**. 

>NOTE: This health check is quite rudimentary, and was written only for the purpose of demonstrating how to check our services are working. It will fail should the internet connection between you and the host were interrupted. Response time can also be affected by your network traffic.


>A more robust check would involve a series of services running on each container, proxy, and outside our swarm. 


> - The one running on the container would send an all-is-well signal at an interval either to a #Slack channel, email account or destination of your choice. Call it a dead-man switch. Whenever the signal stops coming, we know there is a problem with that container.
> - The one running on the proxy would check whether BLUE and GREEN are responding, and report any failure to one of the channels. It too should also send its own all-is-well signal so we know if it dies. 
> - The one running outside the cluster would check against it and inform us in case of a timeout. (This one would be similar to our current script).

> That way, we can be sure that

> - a) Whenever we have a failure anywhere on our swarm, it would let us know.
> - b) If one of the health check services were to fail, the all-is-well signal would stop, hence it would not fail silently (like what happened to the people at GitLab with their backup system). 


## Determining the LIVE instance

In order to do so, we just run the **get-live-service.sh** script. It will return the value of the LIVE instance. 

>NOTE: If the instance is undefined, it will issue a warning.


## Switching between LIVE and IDLE instances

The **toggle.sh** script takes care of toggling **LIVE** and **IDLE**. Those will Force the proxy to set the live environment to their respective instances.

>NOTE: If the instance is undefined, it will issue a warning.

## Draining a node

Nodes can be drained with the following command:

	docker node update --availability drain <NODE-ID>

where NODE-ID is the name of the node we want to drain (eg. worker1, worker2, etc)


## Disposing of the services

I wrote no script for such action, but it can be done after stopping the swarm by executing the following commands on the manager node:

	docker service rm scroll-green
	docker service rm scroll-blue

----------

# Bibliographic Material

 - _BlueGreenDeployment, Martin Fowler_ - https://martinfowler.com/bliki/BlueGreenDeployment.html
 - _Using Blue-Green Deployment to Reduce Downtime and Risk_ - https://docs.cloudfoundry.org/devguide/deploy-apps/blue-green.html

 - _B/G deployment_ - https://lostechies.com/gabrielschenker/2016/05/23/blue-green-deployment/

 - _B/G deployment, using containers_ - https://blog.tutum.co/2015/06/08/blue-green-deployment-using-containers/

 - _Blue/Green deployment with HAproxy_ - https://www.reddit.com/r/sysadmin/comments/53h919/blue_green_deployment_with_haproxy/

 - _Docker flow_ - https://technologyconversations.com/2016/04/18/docker-flow/

 - _Research into doing it with Jenkins_ - https://technologyconversations.com/2015/12/08/blue-green-deployment-to-docker-swarm-with-jenkins-workflow-plugin/

 - _Best practices for writing Dockerfiles_ - https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/
 - _Installing Docker Machine_ - https://docs.docker.com/machine/install-machine/#installing-machine-directly

 - _Docker in production environments_ - https://docs.docker.com/compose/production/

 - _Zero downtime deployment with docker_ - https://medium.com/@korolvs/zero-downtime-deployment-with-docker-d9ef54e48c4#.kz6wgafyu

 - _Another Zero downtime article_ - https://www.perimeterx.com/blog/zero-downtime-deployment-with-docker/

 - _Bluegreen with haproxy_ - https://github.com/docker/dockercloud-haproxy

 - _Docker compose overview_ - https://docs.docker.com/compose/overview/

 - _How to create a swarm_ - https://docs.docker.com/engine/swarm/swarm-tutorial/create-swarm/

 - _Stacks_ - https://docs.docker.com/docker-cloud/apps/stacks/

 - _Deployment strategies (High Availability)_ - https://docs.docker.com/docker-cloud/infrastructure/deployment-strategies/

 - _Dockerfile reference_ - https://docs.docker.com/engine/reference/builder/

 - _Automated Builds_ - https://docs.docker.com/docker-cloud/builds/automated-build/

 - _Reload a Linux users-group assignments without logging out_ - https://superuser.com/questions/272061/reload-a-linux-users-group-assignments-without-logging-out

 - _GitLab postmortem, or as I like to call it: "Criminal Negligence: how all went to hell because we didn't check that our backup mechanisms were working properly, nor we cared to run a simulacrum of our disaster recovery procedure in order to determine if it did work as intended"_ - https://about.gitlab.com/2017/02/10/postmortem-of-database-outage-of-january-31/

 - _Pushing to a git remote_ - https://help.github.com/articles/pushing-to-a-remote/

 - _Removing leading zeroes from a variable in bash_ - https://coderwall.com/p/cobcna/bash-removing-leading-zeroes-from-a-variable

 - _Curl get response time_ - https://viewsby.wordpress.com/2013/01/07/get-response-time-with-curl/

 - _How to dockerize a nodejs app_ - https://nodejs.org/en/docs/guides/nodejs-docker-webapp/

 - _Bash seems not to like floating point numbers..._ - http://stackoverflow.com/questions/19597962/bash-illegal-number

 - _Swarm mode overview_ - https://docs.docker.com/engine/swarm/

 - _Swarm mode key concepts_ - https://docs.docker.com/engine/swarm/key-concepts/

 - _Swarm mode tutorial_ - https://docs.docker.com/engine/swarm/swarm-tutorial/

 - _Blue green with swarm and Jenkins_ - https://technologyconversations.com/2015/07/02/scaling-to-infinity-with-docker-swarm-docker-compose-and-consul-part-34-blue-green-deployment-automation-and-self-healing-procedure/

 - _Load-balancing with nginx_ - https://www.nginx.com/resources/admin-guide/load-balancer/

 - _Nginx reload with no downtime_ - http://serverfault.com/questions/378581/nginx-config-reload-without-downtime

----------

# Afterthoughts

As you can see, Deployment is now way easier using the blue/green technique. Also almost totally painless and very fast.

Add some Ansible/Jenkins magic to this solution, and you can have a fully automated CI/CD pipeline running in no time. Nowadays, the path to the MVP is almost a joyride.

On a more personal note, this was quite the journey. Before starting, I saw myself as a knowledgeable sysop, yet diving into this I discovered a whole new world I wasn't previously aware of. I'm already thinking on ways to improve this (quite basic) solution further.

----------

# Backlog

> - Write a script to automate installation and setup of the swarm
> - Improve control scripts to consider the result of each command before proceeding to the next one
> - Add a 3rd service, where the latest version of the app would be autodeployed for testing purposes whenever someone does a git push.

----------

# Updates

## Update 2017-03-22

>Added control scripts and finished testing the solution. Also wrote the remaining entries on the readme file.

## Update 2017-03-17

>The solution got modified to run as a swarm using docker swarm. It is now much more simple and less error-prone than the previous version, and also uses the latest technology offered by Docker as of this date.
