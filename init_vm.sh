#!/bin/bash

sudo apt -y update

sudo apt -y install net-tools
sudo apt-get -y install apache2
sudo apt-get -y install mysql-server mysql-client
sudo apt-get -y install php7.4 php7.4-mysql libapache2-mod-php7.4

sudo service apache2 restart