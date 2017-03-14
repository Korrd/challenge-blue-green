#!/bin/bash

# 2017-03-06
# Script created by Victor Martin as part of a series intended to demonstrate 
# the blue-green (or is it A/B?, Red-Black?, Something/Else?) approach to a
# zero-downtime deployment.

# This needs to be run with root privileges, so sudo it!

# For more information, hit the readme.md from this repo at <repo-address-here>!

tout=30000 #Timeout, in ms.
l=2000 #Response time treshold value, in ms.
logdir="/var/log/challenge" #Logs will be stored here
interval=5 #Time in seconds between checks
siteip="174.138.78.73" #IP address of our site


if [ ! -d "$logdir" ]; then
  echo "Logs directory does not exist. Creating it at $(tput setaf 7)" $logdir "$(tput sgr 0) (I might need root privileges to do so)."
  sudo mkdir $logdir
  sudo chown $(whoami) /var/log/challenge 
fi


echo "All in order. Healthcheck starting. Interval: $(tput setaf 7)every "$interval" seconds$(tput sgr 0)"
echo "Results of this check are being written to $(tput setaf 7)"$logdir"$(tput sgr 0), where each filename corresponds to a different day."

while sleep $interval; do


  tn1="$(curl --max-time "$(($tout / 1000 + 1))" -s -w %{time_total}\\n -o /dev/null "$siteip"/ping)" #Main site query
  tn2="$(curl --max-time "$(($tout / 1000 + 1))" -s -w %{time_total}\\n -o /dev/null "$siteip":8080/ping)" #Deployment site query

  #Remove commas
  tn1=$(echo "$tn1" | sed 's/,//g')
  tn2=$(echo "$tn2" | sed 's/,//g')

  #Remove leading zeros
  tn1=$(echo $tn1 | sed 's/^0*//')
  tn2=$(echo $tn2 | sed 's/^0*//')

  timestamp_time() {
    date +"%H:%M:%S"
  }

  timestamp_date() {
    date +"%Y-%m-%d"
  }

  #File path for log storage.
  outfile=$logdir"/"$(timestamp_date)".log"

  # Checking the main site ====================================

  if [ $tn1 -ge $tout ]; then

    echo "$(tput setaf 1)["$(timestamp_date)"_"$(timestamp_time)"] - WARNING: "$siteip" not responding! Timeout: "$tout"ms$(tput sgr 0)"
    echo "["$(timestamp_time)"] - WARNING: "$siteip":80 not responding! Timeout: "$tout"ms" >> $outfile
  else

    if [ $tn1 -lt $l ]; then
      echo "["$(timestamp_date)"_"$(timestamp_time)"] - "$siteip" $(tput setaf 7)responds in "$tn1"ms.$(tput sgr 0) Treshold: "$l"ms"
      echo "["$(timestamp_time)"] - ["$siteip":80 - OK] "$tn1"ms. Treshold: "$l"ms" >> $outfile
    else
      echo "$(tput setaf 3)["$(timestamp_date)"_"$(timestamp_time)"] - WARNING: "$siteip" taking too long to respond! "$tn1"ms. Treshold: "$l"ms$(tput sgr 0)"
      echo "["$(timestamp_time)"] - WARNING: "$siteip":80 taking too long to respond! "$tn1"ms. Treshold: "$l"ms" >> $outfile
    fi
  fi

  # Checking the Deployment site ==============================

  if [ $tn2 -ge $tout ]; then

    echo "$(tput setaf 1)["$(timestamp_date)"_"$(timestamp_time)"] - WARNING: "$siteip":8080 not responding! Timeout: "$tout"ms$(tput sgr 0)"
    echo "["$(timestamp_time)"] - WARNING: "$siteip":8080 not responding! Timeout: "$tout"ms" >> $outfile
  else

    if [ $tn2 -lt $l ]; then
      echo "["$(timestamp_date)"_"$(timestamp_time)"] - "$siteip":8080 $(tput setaf 7)responds in "$tn2"ms.$(tput sgr 0) Treshold: "$l"ms"
      echo "["$(timestamp_time)"] - ["$siteip":8080 - OK] "$tn2"ms. Treshold: "$l"ms" >> $outfile
    else
      echo "$(tput setaf 3)["$(timestamp_date)"_"$(timestamp_time)"] - WARNING: "$siteip":8080 taking too long to respond! "$tn2"ms. Treshold: "$l"ms$(tput sgr 0)"
      echo "["$(timestamp_time)"] - WARNING: "$siteip":8080 taking too long to respond! "$tn2"ms. Treshold: "$l"ms" >> $outfile
    fi
  fi

done


# *** EOF ***

