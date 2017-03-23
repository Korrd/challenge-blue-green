#!/bin/bash

# 2017-03-21
# Script created by Victor Martin as part of a series intended to demonstrate 
# the blue-green approach to a zero-downtime deployment.

# This script deploys a new version of our software to the blue service. It requires
# the image tag as a parameter.

# For more information, see the readme file at 
# https://github.com/Korrd/challenge-blue-green

if [ $# -eq 0 ];
  then
    echo "No arguments provided. Usage: "
    echo "sh deploy-blue.sh [image-tag]"
    echo "Aborted"
    exit 1
else
	echo "Determining live environment..."
	live=$(cat /var/live)

	if [ "$live" = "blue" ]; then
	  echo "LIVE service is $(tput setaf 4)"$live"$(tput sgr 0)"

	  echo "$(tput setaf 1) **** WARNING: YOU ARE DEPLOYING TO THE LIVE SERVICE!!!! ****"
	  read -p "Are you sure you want to continue? <y/N>$(tput sgr 0)" prompt

	  if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]]; then

		echo "Deployment in progress..."

		docker service update --image korrd2/challenge-bg-scroll:$1 blue-service

		echo "Finished!"

	  else
		echo "Deployment aborted!"
		exit 1
	  fi

	elif [ "$live" = "green" ]; then
	  echo "LIVE service is $(tput setaf 2)"$live"$(tput sgr 0)"
	  echo "Deploying to $(tput setaf 4)GREEN...$(tput sgr 0)"

		docker service update --image korrd2/challenge-bg-scroll:$1 green-service

	  echo "Finished!"

	else

	  echo "WARNING: current LIVE environment is $(tput setaf 1)UNDEFINED$(tput sgr 0). Run toggle.sh with either 'blue' or 'green' as an argument to set it up." 
	  echo "Deployment Aborted."
	  exit 1
	fi
fi

# *** EOF ***

