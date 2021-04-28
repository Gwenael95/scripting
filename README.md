# scripting
cours de scripting sur linux


#deploiement du serveur

##Préparation du server

###Configuration de la VM
Configuré le reseau de la VM sur 'bridge' (acces par pont).
Nous travaillons sous environnement Linux (Ubuntu) pour
créer un serveur web.

Pour toutes ces commandes, il est probable que vous deviez avoir
les droits sudo

###SSH
Sur votre serveur web, utilisé
```sudo apt install net-tools```, 
afin de pouvoir utiliser la commande ```ifconfig```

Cela vous permettra de recuperer l'adresse IP du serveur
pour se connecter en ssh (ex:192.168.1.30). 
Elle devrait se trouver dans la section enp0s3, inet.

Pour se connecter à votre VM depuis un terminal exterieur, 
entrer la commande ```ssh nomDeLutilisateur@ip``` 
(ex: coding@192.168.1.30). 

Un mot de passe devrait être demandé, celui de l'utilisateur
créer sur la VM linux.
A la première connexion, une question nous sera posé pour 
gerer des clés, permettant de ne plus
entrer de mot de passe a chaque connexion. On peut
bien sûr entrer yes ou no.

###Apache
Sur votre serveur web, utilisé la commande 
```sudo apt install apache2```.
pour tester que le service apache fonctionne bien, 
on peut aller sur un navigateur et saisir ```http://ip``` 
(ex: http://192.168.1.30). On devra arriver sur une page 
avec une page par defaut de ubuntu.


###DNS
Pour configurer les DNS, nous commenceront par 
la commande ```vi /etc/hosts``` côté serveur web.
On ajoute alors une ligne ```ip nomDuDomaine``` 
(ex: 192.168.1.30  coding.com). On peut ajouter plusieurs
ligne avec cette même ip, ce seront tous des alias amenant au
même site.

Dans un second temps, comme nous travaillons en local, il faut
egalement modifier le fichier /etc/hosts de notre machine 
(Mac, Windows, Linux).

Pour Mac et Linux, on doit pouvoir suivre les instructions précédente
pour le DNS en mettant à jour ```/etc/hosts```.
Sur Windows, cela diffère. @todo brian : expliquez la demarche a suivre

On doit pouvoir acceder à notre site depuis un navigateur via l'url
```http://nomDuDomaine``` (ex: http://coding.com).

###VirtualHost
Une fois qu'apache est installé sur le serveur, 
on peut s'occuper du virtual host.
- Entrer la commande ```cd /etc/apache2/site-available```
- ```vi nomDuDomaine.conf```, (ex:vi coding.com.conf)
- Ajouté au minimum ces quelques lignes:
```
<VirtualHost *:80>
	DocumentRoot /var/www/coding.com
	ServerName coding.com
</VirtualHost>
```
Remplacé bien sûr 'coding.com' par le nom de votre domaine.

- Utilisé la commande ```a2ensite nomDuDomaine``` 
(ex: a2ensite coding.com).
- On relance apache avec la commande 
```systemctl reload apache2```

[si la commande ne fonctionne pas et renvoie une erreur
```apache2.service is not active, cannot reload.```, 
essayer d'entrer les commandes : ```apachectl stop```, 
```/etc/init.d/apache2 start```
```/etc/init.d/apache2 reload```.
]

###Wordpress

####Mysql 
Afin de pouvoir utiliser wordpress, nous allons avoir besoin 
d'installer mysql et de créer des tables.

On commence donc par saisir la commande 
```apt install mysql-server mysql-client``` sur notre server web.

Créons maintenant la base données et un utilisateur avec la commande
````
mysql -u root <<EOFMYSQL
CREATE DATABASE wordpress CHARACTER SET UTF8 COLLATE UTF8_BIN;
CREATE USER 'wordpress'@'%' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'%';
FLUSH PRIVILEGES;
EOFMYSQL
````
On peut remplacer 'wordpress' par tout autre nom d'utilisateur, 
et 'password' par un mot de passe plus sécurisé dans cette requête.

####Apache
On doit ajouter certaines librairies pour utiliser wordpress
tel que php.

Sur le serveur web, saisir la commande 
```apt install php php-mysql libapache2-mod-php```.
Php et maintenant installé, il faut relancer apache, utilisé 
la commande ```service apache2 restart```

####fichiers wordpress
On peut installer wordpress sur le serveur.
Plaçons nous d'abord dans le dossier ```/tmp```.
Entrer ensuite les commandes:
```
wget https://wordpress.org/latest.tar.gz
tar -zxvf latest.tar.gz
mv wordpress/* /var/www/nomDuDomaine/
chown www-data.www-data /var/www/nomDuDomaine/* -R
cp wp-config-sample.php wp-config.php
vi wp-config.php
```

A l'interieur de ce fichier, on mettra les informations
de notre base de données au ligne correpondante.
```
define('DB_NAME', 'wordpress');
define('DB_USER', 'wordpress');
define('DB_PASSWORD', 'password');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');
```

