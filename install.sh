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
printf "server {\n\tlisten 8000;\n\troot /var/www/html/fos-streaming;\n\tindex index.php index.html index.htm;\n\tserver_tokens off;\n\tchunked_transfer_encoding off;\n\trewrite ^/live/(.*)/(.*)/(.*)$ /stream.php?username=\$1&password=\$2&stream=\$3 break;\n\tlocation ~ \.php$ {\n\t\ttry_files \$uri =404;\n\t\tfastcgi_index index.php;\n\t\tfastcgi_pass unix:/run/php/php7.1-fpm.sock;\n\t\tinclude fastcgi_params;\n\t\tfastcgi_keep_conn on;\n\t\tfastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;\n\t\tfastcgi_param SCRIPT_NAME \$fastcgi_script_name;\n\t}\n}\n" > /etc/nginx/sites-available/fos-streaming
ln -s /etc/nginx/sites-available/fos-streaming /etc/nginx/sites-enabled/
/etc/init.d/nginx restart
curl "http://127.0.0.1:8000/install_database_tables.php?install"
curl "http://127.0.0.1:8000/install_database_tables.php?update"
rm /var/www/html/fos-streaming/install_*
