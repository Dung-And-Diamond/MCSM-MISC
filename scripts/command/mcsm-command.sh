#!/bin/bash

#
# MCSM Command Script
# Contributors: KillerOfPie
#

echo_help() {
  echo "Command could not be recognized. Valid commands are: "
  echo "mcsm panel start        - starts the panel"
  echo "mcsm panel stop         - stops the panel"
  echo "mcsm panel restart      - restarts the panel"
  echo "mcsm panel status       - status of the panel services"
  echo "mcsm installer update   - runs the update script for the panel"
  echo "mcsm update             - runs the update script for the panel"
}

process_sysctl_command() {
  service=$2

  if eval systemctl --legend=false list-unit-files "${service}" <& /dev/null
  then
    systemctl "$1" "${service}"
  else
    echo "Service \`${service}\` not installed, skipping... "
  fi
}

mcsm_installer_download="https://raw.githubusercontent.com/Dung-And-Diamond/MCSM-MISC/main/scripts/install/install-mcsm.sh"
mcsm_script_location="/home/minecraft/MCSManager"

daemon_service="mcsm-daemon.service"
web_service="mcsm-web.service"

arg1=${1,,}
case "$arg1" in
  "panel")
    arg2=${2,,}
    case "$arg2" in
      "start" | "stop" | "restart")
        echo "This command requires sudo, please enter password to continue."
        sudo su || echo "Sudo failed, cancelling..." && kill -INT $$
        process_sysctl_command "$arg2" "$daemon_service"
        process_sysctl_command "$arg2" "$web_service"
        exit
      ;;
      "status")
        process_sysctl_command "$arg2" "$daemon_service"
        process_sysctl_command "$arg2" "$web_service"
      ;;
      *) 
        echo_help
      ;;
    esac
  ;;
  "installer")
    arg2=${2,,}
    case "$arg2" in
    "update")
      echo "This command requires sudo, please enter password to continue."
      sudo su || echo "Sudo failed, cancelling..." && kill -INT $$
      rm -f "$mcsm_script_location/mcsm-installer.sh"
      wget -o="$mcsm_script_location/mcsm-installer.sh" $mcsm_installer_download
      exit
    ;;
    *) 
      echo_help
    ;;
    esac
  ;;
  "update") 
    echo "This command requires sudo, please enter password to continue."
    sudo su || echo "Sudo failed, cancelling..." && kill -INT $$
    eval "$mcsm_script_location/install-mcsm.sh"
    exit
  ;;
  *) 
    echo_help
  ;;
esac