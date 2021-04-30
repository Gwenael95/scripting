#!/bin/bash

########################################################################
# This script is used to deploy a new wordpress site on our server.    #
# We create a new user on server, also on mysql and its database.      #
# We prepare the virtualHost and all config to deploy wordpress easily.#
########################################################################

wget=/usr/bin/wget
tar=/bin/tar

_WORDPRESS="https://fr.wordpress.org/latest-fr_FR.tar.gz"
_TEMPLATE_VH="template_vh"

clear

## region optional args
while getopts n:p:hf flag
do
    case "${flag}" in
        n) PROJECT_NAME=${OPTARG};;
        p) PASSWORD=${OPTARG};;
        h) HELP=true;;
        f) FORCE=true;;
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
  "
  exit 0
fi
## endregion

echo "¤ Deploy website ¤"
echo ""
echo "Be sure to be in 'sudo su' before starting..."
echo "Else, press Ctrl+C and do it!"
echo ""

# get project name and password, in order to create user if not in options
if [ -z "$PROJECT_NAME" ]; then
  read -p "Enter a project name (without extension) : " PROJECT_NAME
fi

echo "Choose your extension:"
echo ""
select extension in "net" "com" "local" "org"
do
  if [ -n "$extension" ] ; then
      echo "You have chosen $extension"
      break
  fi
done

PROJECT_NAME=$PROJECT_NAME.$extension

echo ""
echo "Create project: $PROJECT_NAME"
echo "Confirm your choice:"
echo ""
select confirmation in "yes" "no"
do
  if [ -n "$confirmation" ] ; then
      echo "You have chosen $confirmation"
      if [ $confirmation = "no" ] ; then
        echo "Exit..."
        exit 1
      fi
      break
  fi
done

# check any project has same name
egrep "^$PROJECT_NAME" /etc/passwd >/dev/null
exist=$?
echo $exist

if [ $exist -eq 0 ]; then
  echo "Project $PROJECT_NAME already exists!"
  exit 1
fi

if [ -z "$PASSWORD" ]; then
  PASSWORD=$(</dev/urandom tr -dc _!A-Z-a-z-0-9 | head -c12)
fi
## endregion

## region confirm creation if no -f option
if [ -z "$FORCE" ]; then
  read -p "A new site will be created with user= $PROJECT_NAME and password= $PASSWORD.
 Should we create it? [y/n]" CONFIRM
fi

if ( [ -n "$FORCE" ] && $FORCE) || [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "yes" ] || [ "$CONFIRM" = "Y" ] ; then
    echo "Site for $PROJECT_NAME is ready to be created."
else
    echo "Cancel project."
    exit 0
fi
## endregion

ARR_IN=("${PROJECT_NAME//./}")

USERNAME="${ARR_IN[0]}"

## region create user
sudo useradd -m -G "www-data" -p "$PASSWORD" "$USERNAME"
[ $? -eq 0 ] && echo "User has been added to system!" || echo "Failed to add a user!"
## endregion

sudo bash mysql_create.sh -n "$USERNAME" -p"$PASSWORD"

## region user website folder
mkdir "/var/www/$PROJECT_NAME"
cd "/var/www/$PROJECT_NAME" || return
## endregion

## region wget to download VERSION file
$wget "${_WORDPRESS}"
exist=$?
if [ $exist -ne 0 ]; then
  echo "wget failed"
  exit 1
fi

clear
echo "Wordpress is downloaded"

$tar xvf "latest-fr_FR.tar.gz"

sudo mv "/var/www/$PROJECT_NAME/wordpress/"* "/var/www/$PROJECT_NAME"
sudo rm -r "wordpress"
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

IP_MACHINE=$(hostname -I)
sudo sed -i "1s/^/$IP_MACHINE $PROJECT_NAME\n/" /etc/hosts

sudo sed -i "1s/^/hostname:'$PROJECT_NAME'" "/usr/bin/python/$PROJECT_NAME.yaml"

sudo a2ensite "$PROJECT_NAME.conf"
sudo service apache2 reload
## endregion

echo "Done, please browse to http://$PROJECT_NAME to check!"
