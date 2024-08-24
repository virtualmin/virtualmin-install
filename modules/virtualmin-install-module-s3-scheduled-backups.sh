#!/bin/sh

# Copyright 2005-2024 Virtualmin
# Simple script to configure Virtualmin S3 scheduled backups

S3NAM=${S3NAM:-'Default S3 Backup Server'}
# Environment variables must be set prior
S3KEY=${S3KEY}
S3SEC=${S3SEC}
S3RGN=${S3RGN}
S3END=${S3END}

if [ -z "$S3KEY" ] || [ -z "$S3SEC" ] || [ -z "$S3RGN" ]; then
  log_debug "Virtualmin S3 module: Failed to install '$S3NAM' as the required 'S3KEY', 'S3SEC', and 'S3RGN' environment variables are missing"
else
  # Fixed variables
  ACCOUNT_ID='171977777700000'
  BACKUP_ID='171977777700007'
  CRON_ID='1719777777000770'
  HOSTNAME=$(hostname)

  # Create /root/.aws/config
  mkdir -p /root/.aws
  cat <<EOL >/root/.aws/config
[${ACCOUNT_ID}]
region = ${S3RGN}
EOL

  # Create /root/.aws/credentials
  cat <<EOL >/root/.aws/credentials
[${ACCOUNT_ID}]
aws_access_key_id = ${S3KEY}
aws_secret_access_key = ${S3SEC}
region = ${S3RGN}
EOL

  # Create /etc/webmin/virtual-server/s3accounts/${ACCOUNT_ID}
  mkdir -p /etc/webmin/virtual-server/s3accounts
  cat <<EOL >/etc/webmin/virtual-server/s3accounts/${ACCOUNT_ID}
id=${ACCOUNT_ID}
secret=${S3SEC}
location=${S3RGN}
access=${S3KEY}
desc=${S3NAM}
EOL

  # Add the endpoint if set
  if [ -n "$S3END" ]; then
    echo "endpoint=${S3END}" >>/etc/webmin/virtual-server/s3accounts/${ACCOUNT_ID}
  fi

  # Create /etc/webmin/virtual-server/backups/${BACKUP_ID}
  mkdir -p /etc/webmin/virtual-server/backups
  cat <<EOL >/etc/webmin/virtual-server/backups/${BACKUP_ID}
mkdir=1
email_doms=
plan=
desc=
before=
features=
doms=
id=${BACKUP_ID}
exclude=
fmt=2
virtualmin=
compression=
file=/etc/webmin/virtual-server/backups/${BACKUP_ID}
onebyone=1
special=
errors=0
feature_all=1
days=*
include=
purge=
email=root
mins=0
after=
parent=1
enabled=2
weekdays=*
email_err=1
all=1
months=*
key=
increment=0
strftime=1
kill=0
dest=s3://${ACCOUNT_ID}@${HOSTNAME}/backup-%Y-%m-%d-%H-%M
interval=
ownrestore=0
hours=0,4,8,12,16,20
backup_opts_dir=dirnohomes=0,dirnologs=0
EOL

  # Create /etc/webmin/virtual-server/backup.pl with 755 permissions
  cat <<'EOL' >/etc/webmin/virtual-server/backup.pl
#!/usr/bin/perl
open(CONF, "</etc/webmin/miniserv.conf") || die "Failed to open /etc/webmin/miniserv.conf : $!";
while(<CONF>) {
        $root = $1 if (/^root=(.*)/);
        }
close(CONF);
$root || die "No root= line found in /etc/webmin/miniserv.conf";
$ENV{'PERLLIB'} = "$root";
$ENV{'WEBMIN_CONFIG'} = "/etc/webmin";
$ENV{'WEBMIN_VAR'} = "/var/webmin";
delete($ENV{'MINISERV_CONFIG'});
chdir("$root/virtual-server");
exec("$root/virtual-server/backup.pl", @ARGV) || die "Failed to run $root/virtual-server/backup.pl : $!";
EOL
  chmod 755 /etc/webmin/virtual-server/backup.pl

  # Create /etc/webmin/webmincron/crons/${CRON_ID}.cron
  mkdir -p /etc/webmin/webmincron/crons
  cat <<EOL >/etc/webmin/webmincron/crons/${CRON_ID}.cron
arg0=backup.pl
months=*
active=1
special=
interval=
func=run_cron_script
hours=0,4,8,12,16,20
days=*
mins=0
user=root
arg1=--id ${BACKUP_ID}
id=${CRON_ID}
module=virtual-server
weekdays=*
EOL
  log_debug "Virtualmin S3 module: '$S3NAM' was successfully installed."
fi
