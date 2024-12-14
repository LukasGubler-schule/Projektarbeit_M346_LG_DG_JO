#!/bin/bash

# Variablen für allgemeine Einstellungen
REGION="us-east-1"  # Region explizit festlegen
AMI_ID="ami-0dba2cb6798deb6d8"  # Ubuntu Server 22.04 AMI für us-east-1
INSTANCE_TYPE="t2.micro"  # EC2-Instanztyp
SECURITY_GROUP_NAME="WebServerSG"  # Sicherheitsgruppenname
TAG_NAME="MyUbuntuServer"  # Tag für die Instanzen

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
    --description "Sicherheitsgruppe fuer Webserver" \
    --query 'GroupId' \
    --output text)

if [ $? -ne 0 ]; then
    echo "Fehler beim Erstellen der Sicherheitsgruppe."
    exit 1
fi

echo "Sicherheitsgruppe erstellt: $SECURITY_GROUP_ID"

# Ports öffnen (SSH, HTTP, HTTPS)
echo "Öffne Ports für SSH, HTTP und HTTPS..."
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 443 --cidr 0.0.0.0/0

echo "Ports wurden erfolgreich geöffnet."

# EC2-Instanzen erstellen
echo "Erstelle EC2-Instanzen in Region $REGION..."
INSTANCE_IDS=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 2 \
    --instance-type $INSTANCE_TYPE \
    --security-group-ids $SECURITY_GROUP_ID \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$TAG_NAME}]" \
    --query 'Instances[*].InstanceId' \
    --output text)

if [ $? -eq 0 ]; then
    echo "Instanzen erfolgreich erstellt: $INSTANCE_IDS"
else
    echo "Fehler beim Erstellen der Instanzen."
    exit 1
fi

# Ausgabe der Instanzdetails
echo "Instanzdetails:"
aws ec2 describe-instances --instance-ids $INSTANCE_IDS --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress,State.Name]' --output table

echo "Skript abgeschlossen."
