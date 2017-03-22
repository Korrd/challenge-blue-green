#!/bin/bash

# 2017-03-20
# Script created by Victor Martin as part of a series intended to demonstrate 
# the blue-green approach to a zero-downtime deployment.

# This script checks and reports the currently live service

# For more information, see the readme file at 
# https://github.com/Korrd/challenge-blue-green

LIV=$(cat /var/live)

if [ $LIV = "blue" ];
  then

    echo -n "$(tput setaf 4)"
    echo "The live service is: "$LIV

elif [ $LIV = "green" ];
  then

  echo -n "$(tput setaf 2)"
  echo "The live service is: "$LIV

else

  echo -n "$(tput setaf 1)"
  echo "File '/var/live' contains an invalid value: "$LIV". Fix it by running this script with either the 'blue' or 'green' argument. Aborted."

fi

echo -n "$(tput sgr 0)"

# *** EOF ***
