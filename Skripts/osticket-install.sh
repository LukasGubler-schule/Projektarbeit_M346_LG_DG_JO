k#!/bin/bash

# OS Ticket Installationsskript für Ubuntu

set -e

echo "Systempakete werden aktualisiert..."
sudo apt update -y && sudo apt upgrade -y

echo "Erforderliche Pakete werden installiert..."
sudo apt install -y apache2 mysql-server php libapache2-mod-php php-mysql php-intl php-mbstring php-imap php-xml php-cli php-gd unzip wget

echo "Apache-Modul 'rewrite' wird aktiviert..."
sudo a2enmod rewrite
sudo systemctl restart apache2

echo "MySQL-Dienst wird gestartet..."
sudo systemctl enable mysql
sudo systemctl start mysql

# MySQL-Datenbankkonfiguration
echo "Datenbank und Benutzer für OS Ticket erstellen..."
MYSQL_ROOT_PASSWORD="1234" # Sichere Passwort setzen
DB_NAME="osticket"
DB_USER="osticket_user"
DB_PASSWORD="1234"

sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH '1234' BY '${MYSQL_ROOT_PASSWORD}'; FLUSH PRIVILEGES;"
sudo mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "CREATE DATABASE ${DB_NAME}; CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}'; GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost'; FLUSH PRIVILEGES;"

echo "Neueste OS Ticket-Version wird heruntergeladen..."
OS_TICKET_VERSION=$(curl -s https://api.github.com/repos/osTicket/osTicket/releases/latest | grep 'tag_name' | cut -d '"' -f 4)
wget https://github.com/osTicket/osTicket/releases/download/${OS_TICKET_VERSION}/osTicket-${OS_TICKET_VERSION}.zip -O osTicket.zip

echo "OS Ticket-Dateien werden entpackt..."
unzip osTicket.zip -d osTicket
sudo mv osTicket/upload/* /var/www/html/
sudo cp /var/www/html/include/ost-sampleconfig.php /var/www/html/include/ost-config.php
sudo chmod 0666 /var/www/html/include/ost-config.php

echo "Dateiberechtigungen werden gesetzt..."
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html

echo "Apache wird konfiguriert..."
cat <<EOF | sudo tee /etc/apache2/sites-available/osticket.conf
<VirtualHost *:80>
    DocumentRoot /var/www/html
    <Directory /var/www/html>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

sudo a2ensite osticket.conf
sudo systemctl reload apache2

echo "OS Ticket wurde erfolgreich installiert. Navigieren Sie in Ihrem Browser zu:"
echo "http://$(curl -s http://checkip.amazonaws.com)"

