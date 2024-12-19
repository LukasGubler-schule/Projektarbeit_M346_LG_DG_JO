#!/usr/bin/env bash
set -e

# Konfiguration - bitte anpassen
AWS_REGION="eu-central-1"
AWS_PROFILE="default"
AMI_ID="ami-0c55b159cbfafe1f0"  # Beispiel-AMI für Amazon Linux 2 in eu-central-1
INSTANCE_TYPE="t3.micro"
KEY_NAME="mein-ssh-key"        # Bereits in AWS hinterlegt
SECURITY_GROUP_ID="sg-xxxxxxxxxxxxx" # Sicherheitsgruppe anpassen
DB_TAG="DB-Server"
WEB_TAG="Web-Server"

# Überprüfen ob AWS CLI installiert ist
if ! command -v aws &> /dev/null
then
    echo "AWS CLI nicht gefunden. Versuche es zu installieren..."
    # Beispiel für Linux x86_64:
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip /tmp/awscliv2.zip -d /tmp
    sudo /tmp/aws/install
fi

echo "AWS CLI vorhanden. Erstelle EC2-Instanzen..."

# Datenbank-Instance erstellen
DB_INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SECURITY_GROUP_ID \
    --region $AWS_REGION \
    --profile $AWS_PROFILE \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$DB_TAG}]" \
    --query "Instances[0].InstanceId" \
    --output text)

echo "Datenbank-Instanz erstellt: $DB_INSTANCE_ID"

# Webserver-Instance erstellen
WEB_INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SECURITY_GROUP_ID \
    --region $AWS_REGION \
    --profile $AWS_PROFILE \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$WEB_TAG}]" \
    --query "Instances[0].InstanceId" \
    --output text)

echo "Webserver-Instanz erstellt: $WEB_INSTANCE_ID"

echo "Warte bis beide Instanzen 'running' sind..."
aws ec2 wait instance-running --instance-ids $DB_INSTANCE_ID $WEB_INSTANCE_ID --region $AWS_REGION --profile $AWS_PROFILE
echo "Beide Instanzen sind jetzt am Laufen."

DB_PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $DB_INSTANCE_ID \
    --region $AWS_REGION \
    --profile $AWS_PROFILE \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text)

WEB_PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $WEB_INSTANCE_ID \
    --region $AWS_REGION \
    --profile $AWS_PROFILE \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text)

echo "DB Server IP: $DB_PUBLIC_IP"
echo "Web Server IP: $WEB_PUBLIC_IP"

# Warte kurz, damit SSH-Zugriff gewährleistet ist
echo "Warte 30 Sekunden bevor SSH-Login versucht wird..."
sleep 30

# SSH Optionen (Anpassen je nach Key-Location)
SSH_OPTS="-o StrictHostKeyChecking=no -i ~/.ssh/${KEY_NAME}.pem"

echo "Installiere MySQL auf dem DB-Server..."
ssh $SSH_OPTS ec2-user@$DB_PUBLIC_IP "sudo yum update -y && sudo yum install -y mariadb-server && sudo systemctl enable mariadb && sudo systemctl start mariadb"

echo "Installiere Apache und osTicket auf dem Web-Server..."
ssh $SSH_OPTS ec2-user@$WEB_PUBLIC_IP "sudo yum update -y && sudo yum install -y httpd php php-mysqlnd php-fpm unzip"
ssh $SSH_OPTS ec2-user@$WEB_PUBLIC_IP "sudo systemctl enable httpd && sudo systemctl start httpd"

# osTicket installieren (Beispiel - aktuellste Version prüfen!)
OS_TICKET_VERSION="v1.17"
OS_TICKET_URL="https://github.com/osTicket/osTicket/releases/download/${OS_TICKET_VERSION}/osTicket-${OS_TICKET_VERSION}.zip"
ssh $SSH_OPTS ec2-user@$WEB_PUBLIC_IP "curl -L $OS_TICKET_URL -o /tmp/osticket.zip && sudo mkdir -p /var/www/html/osticket"
ssh $SSH_OPTS ec2-user@$WEB_PUBLIC_IP "sudo unzip /tmp/osticket.zip -d /var/www/html/osticket"
ssh $SSH_OPTS ec2-user@$WEB_PUBLIC_IP "sudo chown -R apache:apache /var/www/html/osticket && sudo chmod -R 755 /var/www/html/osticket"
ssh $SSH_OPTS ec2-user@$WEB_PUBLIC_IP "sudo systemctl restart httpd"

echo "Fertig! Dein Datenbankserver ist unter $DB_PUBLIC_IP (MySQL installiert) und dein Webserver mit Apache und osTicket unter $WEB_PUBLIC_IP erreichbar."
