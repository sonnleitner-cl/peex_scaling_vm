#!/bin/bash

apt update && apt upgrade -y
apt remove --purge -y apache2 apache2-bin apache2-data apache2-utils
apt install -y apache2 stress
systemctl start apache2
systemctl enable apache2

usermod -a -G www-data ubuntu
chown -R ubuntu:www-data /var/www
chmod 2775 /var/www
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;
cd /var/www/html
hostname -f > index.html
