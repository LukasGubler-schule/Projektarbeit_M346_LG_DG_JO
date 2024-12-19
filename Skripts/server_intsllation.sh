#!/bin/bash

# Variablen für allgemeine Einstellungen
REGION="us-east-1"
AMI_ID="ami-0dba2cb6798deb6d8"
INSTANCE_TYPE="t2.micro"
SECURITY_GROUP_NAME="WebServerSG"
TAG_NAME_INSTANCE_1="Webserver_TicketsystemInstallation"
TAG_NAME_INSTANCE_2="Dateiserver_TicketsystemInstallation"
KEY_NAME_1="key-Webserver-Ticketinstallation"  
KEY_NAME_2="key-Dateiserver-Ticketinstallation"  

# AWS Credentials abfragen
echo "Bitte gib deine AWS Access Key ID ein:"
read -r AWS_ACCESS_KEY_ID
echo "Bitte gib deinen AWS Secret Access Key ein:"
read -r AWS_SECRET_ACCESS_KEY
echo "Bitte gib deinen AWS Session Token ein (falls vorhanden):"
read -r AWS_SESSION_TOKEN

# AWS CLI Umgebungsvariablen setzen
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN
export AWS_DEFAULT_REGION=$REGION

# Sicherheitsgruppe erstellen
echo "Erstelle Sicherheitsgruppe $SECURITY_GROUP_NAME in Region $REGION..."
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name $SECURITY_GROUP_NAME \
    --description "Security group for web servers" \
    --query 'GroupId' \
    --output text)

if [ $? -ne 0 ]; then
    echo "Fehler beim Erstellen der Sicherheitsgruppe."
    exit 1
fi

echo "Sicherheitsgruppe erstellt: $SECURITY_GROUP_ID"


$KEY_DIR="~/.ssh/"


# Key Pair 1 erstellen
echo "Erstelle Key Pair $KEY_NAME_1..."
KEY_FILE_1="$KEY_DIR/$KEY_NAME_1.pem"
aws ec2 create-key-pair \
    --key-name $KEY_NAME_1 \
    --query 'KeyMaterial' \
    --output text > $KEY_FILE_1

#Checkpoint
if [ $? -ne 0 ]; then
    echo "Fehler beim Erstellen von Key Pair $KEY_NAME_1."
    exit 1
fi



chmod 400 $KEY_FILE_1
echo "Key Pair 1 erstellt und gespeichert in $KEY_FILE_1."

# Key Pair 2 erstellen
echo "Erstelle Key Pair $KEY_NAME_2..."
KEY_FILE_2="$KEY_DIR/$KEY_NAME_2.pem"
aws ec2 create-key-pair \
    --key-name $KEY_NAME_2 \
    --query 'KeyMaterial' \
    --output text > $KEY_FILE_2

if [ $? -ne 0 ]; then
    echo "Fehler beim Erstellen von Key Pair $KEY_NAME_2."
    exit 1
fi

chmod 400 $KEY_FILE_2
echo "Key Pair 2 erstellt und gespeichert in $KEY_FILE_2."

# Weitere Befehle wie im ursprünglichen Skript...

# Ports öffnen (SSH, HTTP, HTTPS)
echo "Öffne Ports für SSH, HTTP und HTTPS..."
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 443 --cidr 0.0.0.0/0

echo "Ports wurden erfolgreich geöffnet."

# Webserver EC2-Instanzen erstellen
echo "Erstelle Webserver EC2-Instanzen in Region $REGION..."
INSTANCE_ID_Webserver=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME_1 \
    --security-group-ids $SECURITY_GROUP_ID \
    --tag-specifications "ResourceType=instance, Tags=[{Key=Name,Value=$TAG_NAME_INSTANCE_1}]" \
    --query 'Instances[*].InstanceId' \
    --output text)

if [ $? -eq 0 ]; then
    echo "Instanz Webserver erfolgreich erstellt: $TAG_NAME_INSTANCE_1"
else
    echo "Fehler beim Erstellen der Instanzen."
    exit 1
fi

# Webserver EC2-Instanzen erstellen
echo "Erstelle Webserver EC2-Instanzen in Region $REGION..."
INSTANCE_ID_Dateiserver=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME_2 \
    --security-group-ids $SECURITY_GROUP_ID \
    --tag-specifications "ResourceType=instance, Tags=[{Key=Name,Value=$TAG_NAME_INSTANCE_2}]" \
    --query 'Instances[*].InstanceId' \
    --output text)

if [ $? -eq 0 ]; then
    echo "Instanz Webserver erfolgreich erstellt: $TAG_NAME_INSTANCE_2"
else
    echo "Fehler beim Erstellen der Instanzen."
    exit 1
fi

echo "Abwarten bis Server Online"
aws ec2 wait instance-running --instance-ids $INSTANCE_ID_Webserver
aws ec2 wait instance-running --instance-ids $INSTANCE_ID_Dateiserver  

# Abrufen der öffentlichen IP der ersten Instanz
echo "Rufe die öffentliche IP-Adresse der ersten Instanz ab..."
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $(echo $INSTANCE_IDS | awk '{print $1}') --query 'Reservations[*].Instances[*].PublicIpAddress' --output text)

if [ -z "$PUBLIC_IP" ]; then
    echo "Fehler beim Abrufen der öffentlichen IP-Adresse."
    exit 1
fi

echo "Öffentliche IP-Adresse der Instanz: $PUBLIC_IP"

# SSH-Verbindung testen
echo "Teste die SSH-Verbindung zur Instanz..."
ssh -i $KEY_FILE_1 -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP

if [ $? -eq 0 ]; then
    echo "SSH-Verbindung erfolgreich getestet."
else
    echo "Fehler bei der SSH-Verbindung."
    exit 1
fi

echo "erstellen der Instanzen Erfolgreich..."
