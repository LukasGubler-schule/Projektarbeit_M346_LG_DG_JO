#!/bin/bash

# OS Ticket Installationsskript für Ubuntu
# Dieses Skript installiert OS Ticket und fordert den Benutzer auf, die erforderlichen Konfigurationen einzugeben.

set -e

# Funktion für den Fortschrittsbalken
progress_bar() {
    local duration=$1
    local progress=0
    printf "\n"
    while [ $progress -le 100 ]; do
        printf "\r[%-50s] %d%%" $(printf "#%.0s" $(seq 1 $((progress / 2)))) $progress
        sleep $((duration / 20))
        progress=$((progress + 5))
    done
    printf "\n\n"
}

# Benutzer bestätigen, ob die Installation starten soll
echo "Dieses Skript installiert OS Ticket auf Ihrem System. Möchten Sie fortfahren? (ja/nein)"
read confirmation
if [[ "$confirmation" != "ja" ]]; then
    echo -e "\033[1;31mInstallation abgebrochen.\033[0m"
    exit 0
fi

# Hilfsfunktion zur Eingabeaufforderung
prompt_input() {
    read -p "$1: " input
    echo "$input"
}

# Systempakete aktualisieren
echo -e "\033[1;32mSystempakete werden aktualisiert...\033[0m"
progress_bar 10 &
sudo apt update -y &>/dev/null
sudo apt upgrade -y &>/dev/null
wait
printf "\n"
echo -e "\033[1;32mSystempakete wurden erfolgreich aktualisiert.\033[0m\n"
sleep 2

# Erforderliche Abhängigkeiten installieren
echo -e "\033[1;32mErforderliche Pakete werden installiert...\033[0m"
progress_bar 20 &
sudo apt install -y apache2 mysql-server php libapache2-mod-php php-mysql php-intl php-mbstring php-imap php-xml php-cli php-gd unzip wget &>/dev/null
sudo apt install -y php-apcu php-opcache php-json php-phar php-zip &>/dev/null
wait
printf "\n"
echo -e "\033[1;32mPakete wurden erfolgreich installiert.\033[0m\n"
sleep 2

# Erforderliche Apache-Module aktivieren
echo -e "\033[1;32mAktivieren des Apache-Moduls 'rewrite'...\033[0m"
progress_bar 10 &
sudo a2enmod rewrite &>/dev/null
sudo systemctl restart apache2 &>/dev/null
wait
printf "\n"
echo -e "\033[1;32mApache-Modul wurde aktiviert und Apache neu gestartet.\033[0m\n"
sleep 2

# Benutzer nach MySQL-Root-Passwort und Datenbankkonfiguration fragen
mysql_root_password=$(prompt_input "Geben Sie das MySQL-Root-Passwort ein")
os_ticket_db_name=$(prompt_input "Geben Sie den Namen der Datenbank für OS Ticket ein")
os_ticket_db_user=$(prompt_input "Geben Sie den Benutzernamen für die OS Ticket-Datenbank ein")
os_ticket_db_password=$(prompt_input "Geben Sie das Passwort für den Datenbankbenutzer ein")

# E-Mail für ServerAdmin abfragen
server_admin_email=$(prompt_input "Geben Sie die E-Mail-Adresse des Server-Administrators ein")

# Sicherstellen, dass MySQL läuft
echo -e "\033[1;32mSicherstellen, dass der MySQL-Dienst läuft...\033[0m"
progress_bar 5 &
sudo systemctl restart mysql &>/dev/null
sudo systemctl enable mysql &>/dev/null
wait
printf "\n"

# MySQL-Installation manuell konfigurieren
echo -e "\033[1;32mMySQL-Installation wird gesichert...\033[0m"
progress_bar 10 &
echo "ALTER USER 'root'@'localhost' IDENTIFIED WITH 'mysql_native_password' BY '$mysql_root_password';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;" | sudo mysql -u root -p"$mysql_root_password" &>/dev/null
wait
printf "\n"
echo -e "\033[1;32mMySQL-Installation wurde erfolgreich gesichert.\033[0m\n"
sleep 2

# OS Ticket-Datenbank und Benutzer erstellen
echo -e "\033[1;32mDatenbank und Benutzer für OS Ticket werden erstellt...\033[0m"
progress_bar 10 &
echo "CREATE DATABASE $os_ticket_db_name;
CREATE USER '$os_ticket_db_user'@'localhost' IDENTIFIED BY '$os_ticket_db_password';
GRANT ALL PRIVILEGES ON $os_ticket_db_name.* TO '$os_ticket_db_user'@'localhost';
FLUSH PRIVILEGES;" | sudo mysql -u root -p"$mysql_root_password" &>/dev/null
wait
printf "\n"
echo -e "\033[1;32mDatenbank und Benutzer wurden erfolgreich erstellt.\033[0m\n"
sleep 2

# Neueste OS Ticket-Version herunterladen und konfigurieren
echo -e "\033[1;32mNeueste OS Ticket-Version wird heruntergeladen und konfiguriert...\033[0m"
progress_bar 20 &
os_ticket_version=$(curl -s https://api.github.com/repos/osTicket/osTicket/releases/latest | grep 'tag_name' | cut -d '"' -f 4)
cd /var/www/html
sudo wget https://github.com/osTicket/osTicket/releases/download/$os_ticket_version/osTicket-$os_ticket_version.zip &>/dev/null
sudo unzip osTicket-$os_ticket_version.zip -d osTicket &>/dev/null
sudo mv osTicket/upload/* ./
sudo rm -rf osTicket-$os_ticket_version.zip osTicket
wait
printf "\n"
echo -e "\033[1;32mOS Ticket wurde erfolgreich heruntergeladen und konfiguriert.\033[0m\n"
sleep 2

# Überprüfen, ob index.html vorhanden ist, und entfernen
echo -e "\033[1;32mÜberprüfen, ob die Datei index.html existiert, und sie entfernen...\033[0m"
progress_bar 5 &
if [ -f /var/www/html/index.html ]; then
    sudo rm /var/www/html/index.html
    printf "\n"
    echo -e "\033[1;32mindex.html wurde entfernt.\033[0m"
else
    printf "\n"
    echo -e "\033[1;32mindex.html war nicht vorhanden.\033[0m"
fi
wait
printf "\n"

# Fehlende Konfigurationsdatei erstellen
echo -e "\033[1;32mFehlende Konfigurationsdatei wird erstellt...\033[0m"
progress_bar 5 &
sudo cp /var/www/html/include/ost-sampleconfig.php /var/www/html/include/ost-config.php &>/dev/null
sudo chmod 0666 /var/www/html/include/ost-config.php
wait
printf "\n"
echo -e "\033[1;32mKonfigurationsdatei wurde erstellt.\033[0m\n"
sleep 2

# Berechtigungen setzen
echo -e "\033[1;32mBerechtigungen werden gesetzt...\033[0m"
progress_bar 10 &
sudo chown -R www-data:www-data /var/www/html &>/dev/null
sudo chmod -R 755 /var/www/html
wait
printf "\n"
echo -e "\033[1;32mBerechtigungen wurden erfolgreich gesetzt.\033[0m\n"
sleep 2

# Apache-Konfiguration aktualisieren
echo -e "\033[1;32mApache-Konfiguration wird aktualisiert...\033[0m"
progress_bar 10 &
cat <<EOF | sudo tee /etc/apache2/sites-available/osticket.conf &>/dev/null
<VirtualHost *:80>
    ServerAdmin $server_admin_email
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
sudo a2ensite osticket.conf &>/dev/null
sudo systemctl reload apache2 &>/dev/null
wait
printf "\n"
echo -e "\033[1;32mApache-Konfiguration wurde erfolgreich aktualisiert.\033[0m\n"
sleep 2

# Externe IP-Adresse des Servers ermitteln
server_ip=$(curl -s http://checkip.amazonaws.com)

# Abschließende Anweisungen
echo -e "\033[1;32m\n\nOS Ticket wurde erfolgreich installiert.\033[0m"
echo -e "\033[1;32mÖffnen Sie Ihren Browser und navigieren Sie zur folgenden Adresse, um die Installation abzuschließen:\033[0m"
echo -e "\033[1;34mhttp://$server_ip\033[0m"
