#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
which aptitude > /dev/null
if [ $? -eq 0 ]
then
	_APT="aptitude"
else
	_APT="apt-get"
fi

${_APT} update
${_APT} -y full-upgrade

${_APT} -y install nginx-full php-fpm ffmpeg git ca-certificates composer php-mbstring php-zip php-mysql mariadb-server curl

# Securisation database
echo -e "update mysql.user set password=password('$esc_pass') where user='root';\ndelete from mysql.user where user='';\ndelete from mysql.user where user='root' and host not in ('localhost', '127.0.0.1', '::1');\ndelete from mysql.db where db='test' or db='test\\_%';\nflush privileges;\n" | mysql

mysql -uroot -e "create database fosstreaming"
mysql -uroot -e "grant all privileges on fosstreaming.* to 'fosstreaming'@'localhost' identified by 'fosstreaming'"

git clone https://github.com/nmichael000/FOS-Streaming-v1.git /var/www/html/fos-streaming
mkdir /var/www/.composer
chown www-data: /var/www/.composer/
chown -R www-data: /var/www/html/fos-streaming
su - www-data -c "composer install -d /var/www/html/fos-streaming" --shell=/bin/bash
sed -i -e 's/xxx/fosstreaming/g' -e 's/ttt/fosstreaming/g' -e 's/zzz/fosstreaming/g' /var/www/html/fos-streaming/config.php
cp -p /var/www/html/fos-streaming/config/fos-streaming.nginx /etc/nginx/sites-available/fos-streaming
ln -s /etc/nginx/sites-available/fos-streaming /etc/nginx/sites-enabled/
/etc/init.d/nginx restart
curl "http://127.0.0.1:8000/install_database_tables.php?install"
curl "http://127.0.0.1:8000/install_database_tables.php?update"
rm /var/www/html/fos-streaming/install_*
