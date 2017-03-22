#!/bin/bash

# 2017-03-20
# Script created by Victor Martin as part of a series intended to demonstrate 
# the blue-green approach to a zero-downtime deployment.

# This script toggles the LIVE and IDLE services depending on the live service.

# For more information, see the readme file at 
# https://github.com/Korrd/challenge-blue-green

if [ $# -eq 0 ];
  then

  echo "NOTE: If you want to force the service, run this script with either 'blue' or 'green' as an argument."
  echo "Toggling between services..."

  LIV=$(cat /var/live)

  if [ $LIV = "blue" ];
    then

    echo "The live service is: $(tput setaf 4)"$LIV
    echo "$(tput setaf 2)Switching to green$(tput sgr 0)"

    echo -n "green" > /var/live

  elif [ $LIV = "green" ];
    then

    echo "The live service is: $(tput setaf 2)"$LIV
    echo "$(tput setaf 4)Switching to blue$(tput sgr 0)"

    echo -n "blue" > /var/live

  else

    echo "$(tput setaf 1)File '/var/live' contains an invalid value: "$LIV". Fix it by running this script with either the 'blue' or 'green' argument. Aborted.$(tput sgr 0)"

    exit 1
  fi

elif [ $1 = "blue" ];
  then

  echo -n "blue" > /var/live

elif [ $1 = "green" ];
  then

  echo -n "green" > /var/live

else 

  echo "$(tput setaf 1)Invalid value for argument: "$1". Expected 'blue', 'green' or no argument for toggling between services.$(tput sgr 0)"

  exit 1
fi

echo "Done! Reloading nginx."

consul-template -consul-addr=$CONSUL_URL -template="/templates/default.ctmpl:/etc/nginx/nginx.conf:nginx -s reload" -retry 30s -once

