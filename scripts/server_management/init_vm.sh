#!/bin/bash

########################################################################
# This script is used to initialiaze a VM                              #
########################################################################

## $1 is file to copy, $2 destination file, $3 is mod to apply to file if need to be changed
cp_file_in_dir(){
  if [ -f "$1" ] && [ -d "$2" ];
    then
      filename="$(basename "$1")"
      sudo cp "$1" "$2/$filename"
      if [ -n "$3" ]; then
          chmod "$3" "$2/$filename"
      fi
      display_verbose "copy $1 into --> $2"
    else
      display_verbose "$1 not found! Please move it manually at $2"
  fi
}
make_dir(){
  if [ ! -d "$1" ]; then
    mkdir "$1"
    display_verbose "create new dir $1"
  fi
  cd "$1" || return
}

display_verbose(){
  if [ -n "$VERBOSE" ]; then
    echo "$1"
  fi
}

## region constant
SCRIPT=$(readlink -f "$0")
SCRIPT_PATH=$(dirname "$SCRIPT")

TMP_BACKUP_PATH="/tmp/backup"
USR_BIN_PYTHON_PATH="/usr/local/bin/python"

TEMPLATE_PATH="$SCRIPT_PATH/../../templates/template_vh"
FIREWALL_PY_PATH="$SCRIPT_PATH/../firewall/firewall.py"
FIREWALL_CONFIG_PATH="$SCRIPT_PATH/../firewall/config.yaml"
SITES_AVAILABLE="/etc/apache2/sites-available"
USR_BIN_DEPLOYEMENT_PATH="/usr/local/bin"
DEPLOY_PATH="$SCRIPT_PATH/../deployement/deploy_website.sh"
MYSQL_CREATE_PATH="$SCRIPT_PATH/../deployement/mysql_create.sh"
BACKUP_PATH="$SCRIPT_PATH/../backup.sh"
## endregion


## region optional args
while getopts ihv flag
do
  case "${flag}" in
      i) IGNORE_APT=true;;
      h) HELP=true;;
      v) VERBOSE=true;;
  esac
done
## endregion

## region help
if [ -n "$HELP" ]; then
echo "
 Use -h to ask help.
 Use -i to skip apt installation.
 Use -v to display more details about installation when handling files.
"
exit 0
fi
## endregion


clear

COMMON_INTRO="

This script will prepare the server.
It will place all files required into the server.
It will also prepare cron job for backup.sh on your system."


if [ -z "$IGNORE_APT" ]; then
  echo "$COMMON_INTRO

  This script will install :
  net-tools
  tree
  apache2
  openssh-server
  mysql-server mysql-client
  php php-mysql libapache2-mod-php

  "
  read -p "Press enter to start" START

  sudo apt -y update
  sudo apt -y install net-tools
  sudo apt -y install tree
  sudo apt-get -y install apache2
  sudo apt-get -y install openssh-server
  sudo apt-get -y install mysql-server mysql-client
  sudo apt-get -y install php php-mysql libapache2-mod-php
  sudo apt-get install vsftpd

else
  echo "$COMMON_INTRO"
  read -p "Press enter to start" START
fi

clear


make_dir "$TMP_BACKUP_PATH"
make_dir "$USR_BIN_PYTHON_PATH"

cp_file_in_dir "$FIREWALL_PY_PATH" "$USR_BIN_PYTHON_PATH"
cp_file_in_dir "$FIREWALL_CONFIG_PATH" "$USR_BIN_PYTHON_PATH"

cp_file_in_dir "$TEMPLATE_PATH" "$SITES_AVAILABLE"
cp_file_in_dir "$DEPLOY_PATH" "$USR_BIN_DEPLOYEMENT_PATH" "755"
cp_file_in_dir "$MYSQL_CREATE_PATH" "$USR_BIN_DEPLOYEMENT_PATH" "755"
cp_file_in_dir "$BACKUP_PATH" "$USR_BIN_DEPLOYEMENT_PATH" "755" # important for cronjob

## region prepare cron tab job
_BACKUP_JOB_KEY="#cronjob backup"
CRON_JOB="0 1 * * * $USR_BIN_DEPLOYEMENT_PATH/$(basename "$BACKUP_PATH") $_BACKUP_JOB_KEY"

(crontab -l 2>/dev/null | grep -v "$_BACKUP_JOB_KEY"; echo "$CRON_JOB") | crontab -
update-rc.d cron defaults
service cron restart
## endregion


echo ""
sudo service apache2 restart
sudo service vsftpd start

echo "You can find:

firewall.py script and config.yaml at $FIREWALL_PY_PATH (and in your git repository)
Don't forget to edit the config.yaml file after created your website.

You can now execute the deploy_website.sh script in ../deployement"
