#!/bin/bash

########################################################################
# This script is used to deploy a new wordpress site on our server.    #
# We create a new user on server, also on mysql and its database.      #
# We prepare the virtualHost and all config to deploy wordpress easily.#
########################################################################

## region optional args
while getopts n:p:h flag
do
    case "${flag}" in
        n) USERNAME=${OPTARG};;
        p) PASSWORD=${OPTARG};;
        h) HELP=true;;
    esac
done
## endregion

## region help
if [ -n "$HELP" ]; then
  echo "
  use -n to set a user name.
  use -p to set a password.
  "
  exit 0
fi
## endregion

# check are username and password given
if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
  echo "Cannot create a user and database because lack of information."
  exit 1
fi

## region create database, user, with all privileges on his table
_REQUEST="
CREATE DATABASE $USERNAME CHARACTER SET UTF8 COLLATE UTF8_BIN;
CREATE USER '$USERNAME'@'%' IDENTIFIED BY '$PASSWORD';
GRANT ALL PRIVILEGES ON $USERNAME.* TO '$USERNAME'@'%';
FLUSH PRIVILEGES;
"
mysql --user=root <<EOFMYSQL
$_REQUEST
EOFMYSQL
## endregion


