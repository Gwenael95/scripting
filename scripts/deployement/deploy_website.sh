#!/bin/bash

#########################################################################
# This script is used to deploy a new wordpress site on our server.     #
# We create a new user on server, also on mysql and its database.       #
# We prepare the virtualHost and all config to deploy wordpress easily. #
#                                                                       #
# Require mysql_create.sh in same directory.                            #
#########################################################################

## region consts
wget=/usr/bin/wget
tar=/bin/tar

WP_FILE_NAME="latest-fr_FR.tar.gz"
WP_FILE_PATH="/tmp/$WP_FILE_NAME"

_WORDPRESS="https://fr.wordpress.org/latest-fr_FR.tar.gz"
_TEMPLATE_VH="template_vh"
## endregion

## region helper functions
function get_wordpress() {
  cd "/tmp" || return

  if "$1" ; then
    $wget "${_WORDPRESS}"
    exist=$?
    if [ $exist -ne 0 ]; then
      echo "wget ${_WORDPRESS} failed"
      exit 1
    fi
  fi
  $tar xf "$WP_FILE_PATH" # add v next x to Display progress in the terminal
  cd "$OLDPWD" || return
}
function check_project_exist(){
  egrep "^$1" /etc/passwd >/dev/null
  exist=$?

  if [ $exist -eq 0 ]; then
    echo "Project $1 already exists!"
    exit 1
  fi
}
function get_ip(){
  VM_IP="$(ifconfig | grep "inet* 192" | sed "s/ /_/g" | cut -d _ -f 10)"
  if [ -n "$VM_IP" ]; then
      echo "VM ip : $VM_IP"
    else
      ifconfig | grep "inet*"
  fi
}
## endregion

## region optional args
while getopts n:p:hfu flag
do
  case "${flag}" in
      n) PROJECT_NAME=${OPTARG};;
      p) PASSWORD=${OPTARG};;
      h) HELP=true;;
      f) FORCE=true;;
      u) UPDATE_WP=true;;
  esac
done
## endregion

## region help
if [ -n "$HELP" ]; then
  echo "
   Use -h to ask help.
   Use -n to give a project name without extension.
   Use -p to set a password.
   Use -f to force creation (don't ask confirmation).
   Use -u to force download wordpress version (update).
  "
  exit 0
fi
## endregion


clear

## region introduce script
echo "¤ Deploy website ¤

This script will deploy a website.
It will create user on server, mysql user and database, prepare wordpress,
create virtualHost and enable site.

Be sure to be in 'sudo su' before starting...
Else, press Ctrl+C and do it!
"
## endregion

## region get project name and password, in order to create user if not in options
## region project name section
if [ -z "$PROJECT_NAME" ]; then
  read -p "Enter a project name (without extension) : " PROJECT_NAME
fi

# check any project has same name, no need to extension because for 2 site with same username but different extension
# there will be no difference in mysql DB that could lead to issues
check_project_exist "$PROJECT_NAME"

## region choose extension
echo "Choose your extension:"
echo ""
select extension in "net" "com" "local" "org"
  do
  if [ -n "$extension" ] ; then
      echo "You have chosen $extension"
      break
  fi
done

PROJECT_NAME="$PROJECT_NAME.$extension"
## endregion

## endregion

if [ -z "$PASSWORD" ]; then
  PASSWORD=$(</dev/urandom tr -dc _!A-Z-a-z-0-9 | head -c12)
fi
## endregion


## region confirm project creation
echo "
Create project: $PROJECT_NAME, with password= $PASSWORD"
if [ -z "$FORCE" ]; then
  echo "Confirm your choice:"
  echo ""
  select confirmation in "yes" "no"
  do
  if [ -n "$confirmation" ] ; then
      if [ $confirmation = "no" ] ; then
        echo "Cancel project ..."
        exit 1
      fi
      break
  fi
  done
fi
## endregion



## region create users and db
ARR_IN=("${PROJECT_NAME//./}")
USERNAME="${ARR_IN[0]}"

## create user on server
sudo useradd -m -G "www-data" -p "$PASSWORD" "$USERNAME" && echo "User has been added to system!" || (echo "Failed to add a user!" && exit 1)

# create user and database on mysql
sudo bash mysql_create.sh -n "$USERNAME" -p"$PASSWORD"
## endregion

## region wget to download VERSION file
if [ ! -f "$WP_FILE_PATH" ] ; then
  echo "Download wordpress"
  get_wordpress true

else
  # will check if wordpress is recently downloaded, if not we will remove the old one and download a newer version
  echo "$WP_FILE_NAME already downloaded!"
  date_now=$(date +%s)
  date_file=$(date -r "$WP_FILE_PATH" +%s)
  seconds_between=$(("$date_now"-"$date_file"))
  seconds_in_1_week=$((60*60*24*7))

  if [ "$seconds_between" -gt "$seconds_in_1_week" ] || [ -n "$UPDATE_WP" ]; then
    sudo rm "$WP_FILE_PATH"
    echo "Download a newer wordpress version"
    get_wordpress true
  else
    echo "$WP_FILE_NAME previously downloaded extraction"
    get_wordpress false
  fi
fi

## region user website folder
mkdir "/var/www/$PROJECT_NAME"
sudo mv "/tmp/wordpress/"* "/var/www/$PROJECT_NAME"
sudo rm -r "/tmp/wordpress"

cd "/var/www/$PROJECT_NAME" || return
## endregion

## endregion

sudo chmod -R 755 "/var/www/$PROJECT_NAME"

mkdir "/var/log/apache2/$PROJECT_NAME"
cd "/var/log/apache2/$PROJECT_NAME" && touch "error.log" && touch "access.log"
sudo service apache2 reload

## region Prepar wordpress config
DB_NAME=$USERNAME
DB_USER=$USERNAME
DB_PASSWORD=$PASSWORD
DB_HOST="localhost"

TEMP_FILE="/tmp/out.tmp.$$"

# generate wp-config.php by copying wp-config-sample.php
sudo cp "/var/www/$PROJECT_NAME/wp-config-sample.php" "/var/www/$PROJECT_NAME/wp-config.php"
sudo chown www-data.www-data "/var/www/$PROJECT_NAME/"* -R

_DB_DEFINES=('DB_NAME' 'DB_USER' 'DB_PASSWORD' 'DB_HOST' 'WPLANG')

## region loop for update all the config file DB data row
for DB_PROPERTY in "${_DB_DEFINES[@]}" ;
do
  NEW="define('$DB_PROPERTY', '${!DB_PROPERTY}');"  # Will probably need some pretty crazy escaping to allow for better passwords
  sed "/$DB_PROPERTY/s/.*/$NEW/" "/var/www/$PROJECT_NAME/wp-config.php" > $TEMP_FILE && mv $TEMP_FILE "/var/www/$PROJECT_NAME/wp-config.php"
done
## endregion
## endregion

## region enable site
sudo cp "/etc/apache2/sites-available/$_TEMPLATE_VH" "/etc/apache2/sites-available/$PROJECT_NAME.conf"
sudo sed -i "s/__PROJECTNAME__/$PROJECT_NAME/g" "/etc/apache2/sites-available/$PROJECT_NAME.conf"

# prepare DNS on server side
IP_MACHINE=$(hostname -I)
sudo sed -i "1s/^/$IP_MACHINE $PROJECT_NAME\n/" /etc/hosts

# prepare firewall for this project
sudo touch "/usr/local/bin/python/$PROJECT_NAME.yaml"
sudo sed -i "1s/^/hostname: '$PROJECT_NAME'\n/" "/usr/local/bin/python/$PROJECT_NAME.yaml"

sudo a2ensite "$PROJECT_NAME.conf"
sudo service apache2 reload
## endregion

echo "Done, please browse to http://$PROJECT_NAME to check!"
echo "if you're running from VM, don't forget to update your machine /etc/host
with this server ip (can use ifconfig to find it)."
get_ip

