#!/bin/bash

# 2017-03-20
# Script created by Victor Martin as part of a series intended to demonstrate 
# the blue-green approach to a zero-downtime deployment.

# This script scales the green service up or down, depending on the input parameter.

# For more information, see the readme file at 
# https://github.com/Korrd/challenge-blue-green

if [ $# -eq 0 ];
  then
    echo "No arguments provided. Usage: "
    echo "sh scale-green.sh [qty]"
    echo "Aborted"
    exit 1
else
	docker service scale green-service="$1"
fi

# *** EOF ***

