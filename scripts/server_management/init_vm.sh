#!/bin/bash

########################################################################
# This script is used to initialiaze a VM                              #
########################################################################

clear
echo "This script will install :"
echo "net-tools"
echo "tree"
echo "apache2"
echo "openssh-server"
echo "mysql-server mysql-client"
echo "php7.4 php7.4-mysql libapache2-mod-php7.4"
echo ""

sudo apt -y update
sudo apt -y install net-tools
sudo apt -y install tree
sudo apt-get -y install apache2
sudo apt-get -y install openssh-server
sudo apt-get -y install mysql-server mysql-client
sudo apt-get -y install php7.4 php7.4-mysql libapache2-mod-php7.4

TMP_BACKUP_PATH = "/tmp/backup"
USR_BIN_PYTHON_PATH ="/usr/bin/python"
TEMPLATE_PATH = "../../templates/template_vh"
FIREWALL_PY_PATH = "../firewall/firewall.py"
FIREWALL_CONFIG_PATH = "../firewall/config.yaml"
SITES_AVAILABLE = "/etc/apache2/sites-available"
USR_BIN_DEPLOYEMENT_PATH = "/usr/local/bin"

sudo mkdir "$TMP_BACKUP_PATH"
sudo mkdir "$USR_BIN_PYTHON_PATH"

if [ -f "$FIREWALL_PY_PATH" ];
  then
  sudo cp "$FIREWALL_PY_PATH" "$USR_BIN_PYTHON_PATH"
  else
  echo "$FIREWALL_PY_PATH not found! Please move it manually at $USR_BIN_PYTHON_PATH"
fi

if [ -f "$FIREWALL_CONFIG_PATH" ];
  then
  sudo cp "$FIREWALL_CONFIG_PATH" "$USR_BIN_PYTHON_PATH"
  else
  echo "$FIREWALL_CONFIG_PATH not found! Please move it manually at $USR_BIN_PYTHON_PATH"
fi

if [ -f "$TEMPLATE_PATH" ];
  then
  sudo cp "$TEMPLATE_PATH" "$SITES_AVAILABLE"
  else
  echo "$TEMPLATE_PATH not found! Please move it manually at $SITES_AVAILABLE"
fi

sudo service apache2 restart

clear
echo "You can find:"
echo ""
echo "firewall.py script at $FIREWALL_PY_PATH (and in your git repository)"
echo "you can now execute the deploy_website.sh script in ../deployement"
