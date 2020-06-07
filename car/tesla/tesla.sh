#!/bin/sh
#
# tesla.sh --- wrapper script for various tesla commands 
#
# prereq:
# ------
# use tesla_token.sh to obtain your bearer token and use this script
# to obtain the vehicle id (use id command).
#
# Notes:
# ------
# All tesla APIs require bearer token and vehicle id. Since the token 
# and id are very long and inconvenient to type to invoke calls everytime
# i.e. convenience over security :),  the script will look for them in 
# the following location (may be encrypt it openssl?). Anyway, you need get 
# these onetime and store it the files below for all subsequent usage. 
# The bearer token does expires after 45.
#
# $HOME/.mytesla.bearer.token
# $HOME/.mytesla.vehicle.id
#
# Author:  Arul Selvan
# Version: Jun 6, 2020
#
# API reference: https://tesla-api.timdorr.com/
# Client ID & Secret: https://pastebin.com/pS7Z6yyP
#

tesla_api_ep="https://owner-api.teslamotors.com/api/1"
client_id="81527cff06843c8634fdc09e8ac0abefb46ac849f38fe1e431c2ef2106796384"
client_secret="c7257eb71a564034f9419ee651c7d0e5f7aa6bfbd18bafb5c5c033b093bb2fa3"
bearer_token_file="$HOME/.mytesla.bearer.token"
tesla_id_file="$HOME/.mytesla.id"
bearer_token=""
tesla_id=""

usage() {
  echo "Usage: $0 <id|state|wakeup|charge|climate|drive|honk|start|sentry|lock|unlock>\n"
  exit 0
}

check_vehicle_id() {
  if [ -z $tesla_id ] ;  then
    echo "[ERROR] id missing, create the file $tesla_id_file"
    usage
  fi
}

# wakeup, tesla!
wakeup() {
  echo "[INFO] attempting to wake up tesla..."

  # attempt 3 times to wakup and bail if not successful
  for (( i=0; i<3; i++)) ;  do
    response=`curl -s -X POST \
      -H "Cache-Control: no-cache" \
      -H "Content-Type: multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW" \
      -H "Authorization: Bearer $bearer_token" \
      $tesla_api_ep/vehicles/$tesla_id/wake_up 2>&1`
  
    if [[ $response == *state*:*online* ]] ; then
      echo "[INFO] tesla should be awake now."
      return
    fi

    # sleep for sometime
    echo "[INFO] tesla not waking up, will try in 30 sec again..."
    sleep 30
  done
  echo "[WARN] your tesla had too much to drink, not waking up! Try again later."
}

# execute the command
execute() {
  command_route=$1
  curl_request="GET"
  additional_arg=""
  
  if [ ! -z $2 ] ; then
    curl_request=$2
  fi

  if [ ! -z $3 ] ; then
    additional_arg=$3
  fi

  # need to ensure tesla id is present for all commands except "vehicles" to get it
  if [ $command_route != "vehicles" ]; then
    check_vehicle_id
  fi

  # make sure tesla is awake
  wakeup

  echo "[INFO] executing '$curl_request' on route: $tesla_api_ep/$command_route ...\n"
  if [ -z $additional_arg ] ; then
    curl -X $curl_request \
      -H "Cache-Control: no-cache" \
      -H "Content-Type: multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW" \
      -H "Authorization: Bearer $bearer_token" \
      -w "\n\n" \
      $tesla_api_ep/$command_route
  else
    curl -X $curl_request \
      -H "Cache-Control: no-cache" \
      -H "Content-Type: multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW" \
      -H "Authorization: Bearer $bearer_token" \
      -F "$additional_arg" \
      -w "\n\n" \
      $tesla_api_ep/$command_route
  fi
}


# read bearer token and vehicle id.
if [ -f $bearer_token_file ] ; then
  bearer_token=`cat $bearer_token_file`
fi
if [ -f $tesla_id_file ] ;  then
  tesla_id=`cat $tesla_id_file`
fi

if [ -z $bearer_token ] ; then
  echo "[ERROR] bearer token required for all tesla commands!"
  usage
fi

# the commands
case $1 in
  id)
    execute "vehicles"
  ;;
  state)
    execute "vehicles/$tesla_id/data_request/vehicle_state"
  ;;
  wakeup)
    wakeup
  ;;
  charge)
    execute "vehicles/$tesla_id/data_request/charge_state"
  ;;
  climate)
    execute "vehicles/$tesla_id/data_request/climate_state"
  ;;
  drive)
    execute "vehicles/$tesla_id/data_request/drive_state"
  ;;
  honk)
    execute "vehicles/$tesla_id/command/honk_horn" "POST" "on=true"
  ;;
  start)
    # yuk, this needs tesla password! This is a handy command if phone ran out of
    # battery or misplaced or worse lost and you don't have keycard. This command 
    # allows us to unlock car, and drive w/ out keycard or app
    tesla_passwd=$2
    if [ -z $tesla_passwd ] ; then
      echo "[ERROR] start command requires your tesla account password!"
      exit
    fi
    execute "vehicles/$tesla_id/command/remote_start_drive" "POST" "password=$tesla_passwd"
  ;;
  sentry)
    sc=$2
    if [ -z $sc ] ; then
      echo "[ERROR] sentry command requires argument 'true' or 'false'"
      exit
    fi
    case "$sc" in
      true|false)
      execute "vehicles/$tesla_id/command/set_sentry_mode" "POST" "on=$sc"
      ;;
      *)
      echo "[ERROR] sentry argument '$sc' must be 'true' or 'false'"
      exit
      ;;
    esac
  ;;
  lock)
    execute "vehicles/$tesla_id/command/door_lock" "POST" "on=true"
  ;;
  unlock)
    execute "vehicles/$tesla_id/command/door_unlock" "POST" "on=true"
  ;;
  *) usage
  ;;
esac

