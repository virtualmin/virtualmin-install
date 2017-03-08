#!/bin/sh
# virtualmin-install.sh
# Copyright 2005-2017 Virtualmin, Inc.
# Simple script to grab the virtualmin-release and virtualmin-base packages.
# The packages do most of the hard work, so this script can be small-ish and 
# lazy-ish.

# WARNING: Anything not listed in the currently supported systems list is not
# going to work, despite the fact that you might see code that detects your
# OS and acts on it.  If it isn't in the list, the code is not complete and
# will not work.  More importantly, the repos that this script uses do not
# exist, if the OS isn't listed.  Don't even bother trying it.
#
# A manual install might work for you though.
# See here: http://www.virtualmin.com/documentation/installation/manual/

# Currently supported systems:
prosupported=" CentOS/RHEL/Scientific Linux 5, 6, and 7, on x86_64
 Debian 6, 7, and 8, on i386 and amd64
 Ubuntu 12.04 LTS, 14.04 LTS, and 16.04 LTS, on i386 and amd64"
gplsupported=" CentOS/RHEL/Scientific Linux 5, 6, and 7, on x86_64
 Debian 6, 7, and 8, on i386 and amd64
 Ubuntu 12.04 LTS, 14.04 LTS, and 16.04 LTS, on i386 and amd64"

# Some colors and formatting constants
# used in run_ok function.
if type 'tput' > /dev/null; then
	readonly RED=$(tput setaf 1)
	readonly GREEN=$(tput setaf 2)
	readonly YELLOW=$(tput setaf 3)
	readonly REDBG=$(tput setab 1)
	readonly GREENBG=$(tput setab 2)
	readonly YELLOWBG=$(tput setab 3)
	readonly NORMAL=$(tput sgr0)
else
	echo "tput not found, colorized output disabled."
        readonly RED=''
        readonly GREEN=''
        readonly YELLOW=''
        readonly REDBG=''
        readonly GREENBG=''
        readonly YELLOWBG=''
        readonly NORMAL=''
fi

# Unicode checkmark and x mark for run_ok function
readonly CHECK="\u2714"
readonly BALLOT_X="\u2618"

# Make sure Perl is installed
printf "Checking for Perl..."
# loop until we've got a Perl or until we can't try any more
while true; do
	perl=$(which perl 2>/dev/null)
	if [ "$perl" = "" ]; then
        	if [ -x /usr/bin/perl ]; then
                	perl=/usr/bin/perl
			break
                elif [ -x /usr/local/bin/perl ]; then
                	perl=/usr/local/bin/perl
			break
                elif [ -x /opt/csw/bin/perl ]; then
                	perl=/opt/csw/bin/perl
			break
		elif [ $perl_attempted = 1 ] ; then
			echo 'Perl could not be installed - Installation cannot continue.'
			exit 2
		fi
		# couldn't find Perl, so we need to try to install it
       		echo 'Perl was not found on your system - Virtualmin requires it to run.'
		echo 'Attempting to install it now.'
		if [ -x /usr/bin/yum ]; then
			yum -y install perl
		elif [ -x /usr/bin/apt-get ]; then
			apt-get update; apt-get -q -y install perl
		fi
		perl_attempted = 1
		# Loop. Next loop should either break or exit.
	else
		break
	fi
done

printf "found Perl at $perl"
echo ""

log=/root/virtualmin-install.log
skipyesno=0

LANG=
export LANG

while [ "$1" != "" ]; do
	case $1 in
		--help|-h)
		  echo "Usage: $(basename $0) [--uninstall|-u|--help|-h|--force|-f|--hostname]"
			echo "  If called without arguments, installs Virtualmin Professional."
			echo
			echo "  --uninstall|-u: Removes all Virtualmin packages (do not use on a production system)"
			echo "  --help|-h: This message"
			echo "  --force|-f: Skip confirmation message"
			echo "  --hostname|-host: Set fully qualified hostname"
			echo
			exit 0
		;;
		--uninstall|-u)
			mode="uninstall"
		;;
		--force|-f|--yes|-y)
			skipyesno=1
		;;
		--hostname|--host)
			shift
			forcehostname=$1
		;;
		*)
		;;
	esac
	shift
done

SERIAL=GPL
KEY=GPL
VER=6.0.0
echo "$SERIAL" | grep "[^a-z^A-Z^0-9]" && echo "Serial number $SERIAL contains invalid characters." && exit
echo "$KEY" | grep "[^a-z^A-Z^0-9]" && echo "License $KEY contains invalid characters." && exit

arch=$(uname -m)
if [ "$arch" = "i686" ]; then
	arch="i386"
fi
if [ "$SERIAL" = "GPL" ]; then
	LOGIN=""
	PRODUCT="GPL"
	supported=$gplsupported
	repopath="gpl/"
else
	LOGIN="$SERIAL:$KEY@"
	PRODUCT="Professional"
	supported=$prosupported
	repopath=""
fi

# Virtualmin-provided packages
rhvmpackages="usermin webmin wbm-virtualmin-awstats wbm-virtualmin-dav wbm-virtualmin-htpasswd wbm-virtualmin-svn wbm-virtual-server wbm-jailkit"
debvmpackages="usermin webmin webmin-virtualmin-awstats webmin-virtualmin-dav webmin-virtualmin-htpasswd webmin-virtualmin-svn webmin-virtualmin-git webmin-jailkit"
deps=
# Red Hat-based systems 
rhdeps="bind bind-utils caching-nameserver httpd postfix spamassassin procmail perl-DBD-Pg perl-DBD-MySQL quota iptables openssl python mailman subversion mysql mysql-server mysql-devel mariadb mariadb-server postgresql postgresql-server logrotate webalizer php php-xml php-gd php-imap php-mysql php-odbc php-pear php-pgsql php-snmp php-xmlrpc php-mbstring mod_perl mod_python cyrus-sasl dovecot spamassassin mod_dav_svn cyrus-sasl-gssapi mod_ssl ruby ruby-devel rubygems perl-XML-Simple perl-Crypt-SSLeay mlocate perl-LWP-Protocol-https clamav clamav-server clamav-server-systemd clamav-scanner-systemd jailkit"
# Debian
debdeps="bsdutils postfix postfix-pcre webmin usermin ruby libxml-simple-perl libcrypt-ssleay-perl unzip zip libfcgi-dev bind9 spamassassin spamc procmail procmail-wrapper libnet-ssleay-perl libpg-perl libdbd-pg-perl libdbd-mysql-perl quota iptables openssl python mailman subversion ruby irb rdoc ri mysql-server mysql-client mysql-common postgresql postgresql-client awstats webalizer dovecot-common dovecot-imapd dovecot-pop3d proftpd libcrypt-ssleay-perl awstats clamav-base clamav-daemon clamav clamav-freshclam clamav-docs clamav-testfiles libapache2-mod-fcgid apache2-suexec-custom scponly apache2 apache2-doc libapache2-svn libsasl2-2 libsasl2-modules sasl2-bin php-pear php5 php5-cgi libapache2-mod-php5 php5-mysql jailkit"
# Ubuntu (uses odd virtual packaging for some packages that are separate on Debian!)
ubudeps="apt-utils bsdutils postfix postfix-pcre webmin usermin ruby libxml-simple-perl libcrypt-ssleay-perl unzip zip libfcgi-dev bind9 spamassassin spamc procmail procmail-wrapper libnet-ssleay-perl libpg-perl libdbd-pg-perl libdbd-mysql-perl quota iptables openssl python mailman subversion ruby irb rdoc ri mysql-server mysql-client mysql-common postgresql postgresql-client awstats webalizer dovecot-common dovecot-imapd dovecot-pop3d proftpd libcrypt-ssleay-perl awstats clamav-base clamav-daemon clamav clamav-freshclam clamav-docs clamav-testfiles libapache2-mod-fcgid apache2-suexec-custom scponly apache2 apache2-doc libapache2-svn libsasl2-2 libsasl2-modules sasl2-bin php-pear php5 php5-cgi libapache2-mod-php5 php5-mysql jailkit"
# pkg_add-based systems (FreeBSD, NetBSD, OpenBSD)
# FreeBSD php4 and php5 packages conflict, so both versions can't run together
# Many packages need to be installed via ports, and they require custom
# config for each...this sucks.
pkgdeps="p5-Mail-SpamAssassin procmail p5-Class-DBI-Pg p5-Class-DBI-mysql openssl p5-Net-SSLeay python mailman ruby mysql50-server mysql50-client mysql50-scripts postgresql81-server postgresql81-client logrotate awstats webalizer php5 php5-mysql php5-mbstring php5-xmlrpc php5-mcrypt php5-gd php5-dom php5-pgsql php5-session clamav dovecot proftpd unzip p5-IO-Tty mod_perl2"

yesno () {
	if [ "$skipyesno" -eq 1 ]; then
		return 0
	fi
	if [ "$VIRTUALMIN_NONINTERACTIVE" -ne "" ]; then
		return 0
	fi
	while read line; do
		case $line in
			y|Y|Yes|YES|yes|yES|yEs|YeS|yeS) return 0
			;;
			n|N|No|NO|no|nO) return 1
			;;
			*)
			printf "\nPlease enter y or n: "
			;;
		esac
	done
}

# mkdir if it doesn't exist
testmkdir () {
	if [ ! -d "$1" ]; then
		mkdir -p "$1"
	fi
}
# Copy a file if the destination doesn't exist
testcp () {
	if [ ! -e "$2" ]; then
		cp "$1" "$2"
	fi
}
# Set a Webmin directive or add it if it doesn't exist
setconfig () {
	sc_config="$2"
	sc_value="$1"
	sc_directive=$(echo "$sc_value" | cut -d'=' -f1)
	if grep -q "$sc_directive $2"; then
		sed -i -e "s#$sc_directive.*#$sc_value#" "$sc_config"
	else
		echo "$1" >> "$2"
	fi
}
	
# Perform an action, log it, and run the spinner throughout
runner () {
	cmd=$1
	echo "...in progress, please wait..."
	touch busy
	"$srcdir"/spinner busy &
	if $cmd >> $log; then
		rm busy
		sleep 1
		success "$cmd:"
		return 0
	else
		rm busy
		sleep 1
		echo "$cmd failed.  Error (if any): $?"
		echo
		echo "Displaying the last 15 lines of $log to help troubleshoot this problem:"
		tail -15 $log
		return 1
	fi
}

# Perform an action, log it, and print a colorful checkmark or X if failed
# Returns 0 if successful, $? if failed.
run_ok () {
	local cmd=$1
	local msg=$2
	local columns=$(tput cols)
	if [ $columns -ge 80 ]; then
		columns=80
	fi
	COL=$(( ${columns}-${MSG}+${#GREEN}+${#NORMAL} ))

	printf "%s%${COL}s" "$msg"
	if $cmd >> $log; then
    		env printf "$GREENBG[  $CHECK  ]$NORMAL\n"
		return 0
	else
		env printf "$REDBG[  $BALLOT_X  ]$NORMAL\n"
		return $?
	fi
}

fatal () {
	echo
	log_fatal "Fatal Error Occurred: $1"
	printf "${RED}Cannot continue installation.${NORMAL}\n"
	run_ok "remove_virtualmin_release" "Removing software repo configuration, so installation can be re-attempted."
	if [ -x "$tempdir" ]; then
		log_fatal "Removing temporary directory and files."
		rm -rf "$tempdir"
	fi
	log_fatal "If you are unsure of what went wrong, you may wish to review the log"
	log_fatal "in $log"
	exit 1
}

remove_virtualmin_release () {
	case "$os_type" in
		"fedora" | "centos" | "rhel" | "amazon"	)
			rpm -e virtualmin-release
		;;
		"debian" | "ubuntu" )
			grep -v "virtualmin" /etc/apt/sources.list > "$tempdir"/sources.list
			mv "$tempdir"/sources.list /etc/apt/sources.list 
		;;
	esac
}

detect_ip () {
	primaryaddr=$(/sbin/ip -f inet -o -d addr show dev \`/sbin/ip ro ls | grep default | awk '{print $5}'\` | head -1 | awk '{print $4}' | cut -d"/" -f1)
	if [ "$primaryaddr" ]; then
		log_info "Primary address detected as $primaryaddr"
		address=$primaryaddr
		return 0
	else
		log_info "Unable to determine IP address of primary interface."
		echo "Please enter the name of your primary network interface: "
		read primaryinterface
		#primaryaddr=`/sbin/ifconfig $primaryinterface|grep 'inet addr'|cut -d: -f2|cut -d" " -f1`
		primaryaddr=$(/sbin/ip -f inet -o -d addr show dev "$primaryinterface" | head -1 | awk '{print $4}' | cut -d"/" -f1)
		if [ "$primaryaddr" = "" ]; then
			# Try again with FreeBSD format
			primaryaddr=$(/sbin/ifconfig "$primaryinterface"|grep 'inet' | awk '{ print $2 }')
		fi
		if [ "$primaryaddr" ]; then
			log_info "Primary address detected as $primaryaddr"
			address=$primaryaddr
		else
			fatal "Unable to determine IP address of selected interface.  Cannot continue."
		fi
		return 0
	fi
}

set_hostname () {
	i=0
	while [ $i -eq 0 ]; do
		if [ "$forcehostname" = "" ]; then
			printf "Please enter a fully qualified hostname (for example, host.example.com): "
			read line
		else
			log_info "Setting hostname to $forcehostname"
			line=$forcehostname
		fi
		if ! is_fully_qualified "$line"; then
			log_info "Hostname $line is not fully qualified."
		else
			hostname "$line"
			detect_ip
			if grep "$address" /etc/hosts; then
				log_info "Entry for IP $address exists in /etc/hosts."
				log_info "Updating with new hostname."
				shortname=$(echo "$line" | cut -d"." -f1)
				sed -i "s/^$address\([\s\t]+\).*$/$address\1$line\t$shortname/" /etc/hosts
			else
				log_info "Adding new entry for hostname $line on $address to /etc/hosts."
				printf "%s\t%s\t%s\n" \
				  "$address" "$line" "$shortname" >> /etc/hosts
			fi
			i=1
		fi
	done
}
  
is_fully_qualified () {
	case $1 in
		localhost.localdomain)
			log_warning "Hostname cannot be localhost.localdomain."
			return 1
		;;
		*.localdomain)
			log_warning "Hostname cannot be *.localdomain."
			return 1
		;;
		*.*)
			log_success "Hostname OK: fully qualified as $1"
			return 0
		;;
	esac
	log_warning "Hostname $name is not fully qualified."
	return 1
}

success () {
	log_success "$1 Succeeded."
}

# Function to find out if Virtualmin is already installed, so we can get
# rid of some of the warning message. Nobody reads it, and frequently
# folks run the install script on a production system; either to attempt
# to upgrade, or to "fix" something. That's never the right thing.
is_installed () {
	if [ -f /etc/virtualmin-license |]; then
		# looks like it's been installed before
		return 1
	fi
	# XXX Probably not installed? Maybe we should remove license on uninstall, too.
	return 0
}

# This function performs a rough uninstallation of Virtualmin
# It is neither complete, nor correct, but it almost certainly won't break
# anything.  It is primarily useful for cleaning up a botched install, so you
# can run the installer again.
uninstall () {
	# This is a crummy way to detect package manager...but going through 
	# half the installer just to get here is even crummier.
	if type rpm>/dev/null; then package_type=rpm
	elif type dpkg>/dev/null; then package_type=deb
	fi

	case $package_type in
		rpm)
			rpm -e --nodeps virtualmin-base
			rpm -e --nodeps wbm-virtual-server wbm-virtualmin-htpasswd wbm-virtualmin-dav wbm-virtualmin-mailman wbm-virtualmin-awstats wbm-virtualmin-svn wbm-php-pear wbm-ruby-gems wbm-virtualmin-registrar wbm-virtualmin-init wbm-jailkit
			rpm -e --nodeps wbt-virtual-server-mobile
			rpm -e --nodeps webmin usermin awstats
		;;
		deb)
			dpkg --purge virtualmin-base
			dpkg --purge webmin-virtual-server webmin-virtualmin-htpasswd webmin-virtualmin-dav webmin-virtualmin-mailman webmin-virtualmin-awstats webmin-virtualmin-svn webmin-php-pear webmin-ruby-gems webmin-virtualmin-registrar webmin-virtualmin-init webmin-jailkit
			dpkg --purge webmin-virtual-server-mobile
			dpkg --purge webmin usermin
			apt-get clean
		;;
		*)
			echo "I don't know how to uninstall on this operating system."
		;;
	esac
	remove_virtualmin_release
	run_ok "rm /etc/virtualmin-license" "Removing /etc/virtualmin-license"
	echo "Done.  There's probably quite a bit of related packages and such left behind"
	echo "but all of the Virtualmin-specific packages have been removed."
	exit 0
}

# XXX Needs to move after os_detection
if [ "$mode" = "uninstall" ]; then
	uninstall
fi

cat <<EOF

Welcome to the Virtualmin ${GREEN}$PRODUCT${NORMAL} installer, version ${GREEN}$VER${NORMAL}

                      ${RED}WARNING${NORMAL}

 The installation is quite stable and functional when run on a freshly
 installed supported Operating System.

 Please read the Virtualmin Administrators Guide before proceeding if
 your system is not a freshly installed and supported OS.

 This script is not intended to update your system!  It should only be
 used to perform your initial Virtualmin installation.  Updates and 
 upgrasdes can be performed from within Virtualmin or via the system
 package manager. License changes can be performed with the
 "virtualmin change-license" command.

 The systems currently supported by install.sh are:
EOF
echo "$supported"
cat <<EOF

 If your OS/version is not listed above, this script will fail. More 
 details about the systems supported by the script can be found here:

   http://www.virtualmin.com/os-support
 
EOF
printf " Continue? (y/n) "
if ! yesno; then 
	exit
fi

# Double check if installed, just in case above error ignored.
if is_installed; then
cat <<EOF
 Virtualmin may already be installed. This can happen if an installation failed,
 and can be ignored in that case.

 But, if Virtualmin is already successfully installed you should not run this script
 again. Updates and upgrade can be performed from within Virtualmin.

 To change license details, use the 'virtualmin change-license' command. Changing 
 the license inever requires reinstallation.

EOF
	printf " Really Continue? (y/n) "
	if ! yesno; then
		exit
	fi
fi

get_mode () {
cat <<EOF
 FULL or MINIMAL INSTALLATION
 It is possible to install only the minimum set of components and 
 and perform no configuration changes to existing mail/web/DNS 
 or packages.  This mode of installation is called the minimal mode
 because only Webmin, Usermin and the Virtualmin-related modules and
 themes are installed.  The minimal mode will not modify your
 existing configuration.  The full install is recommended if
 this system is a fresh install of the OS.  If your system has
 a working Virtualmin GPL installation using components other than
 our defaults, or you already have virtual hosts, users, mailboxes, 
 etc. configured manually or with another administration tool, the 
 minimal mode is a much safer choice.

EOF

	printf " Would you like to perform a full installation? (y/n) "
	if yesno; then mode=full
	else mode=minimal
	fi

	echo "Installation type: $mode"
	sleep 3
}

# Set the mode (switch to get_mode when 
# minimal mode is finished)
#get_mode
mode=full

virtualminmeta="virtualmin-base"
# If minimal, we don't install any extra packages, or perform any configuration
if [ "$mode" = "minimal" ]; then
	rhdeps=debdeps=ubudeps=pkgdeps=""
	virtualminmeta=$rhvmpackages
fi

# Check for localhost in /etc/hosts
grep localhost /etc/hosts >/dev/null
if [ "$?" != 0 ]; then
	echo "There is no localhost entry in /etc/hosts. This is required, so one will be added."
	run_ok "echo 127.0.0.1 localhost >> /etc/hosts" "Editing /etc/hosts"
	if [ $? -ne 0 ]; then
		log_info "Failed to configure a localhost entry in /etc/hosts."
		log_info "This may cause problems, but we'll try to continue."
	fi
fi

# Check for wget or curl or fetch
printf "Checking for HTTP client..."
while true; do
	if [ -x "/usr/bin/curl" ]; then
		download="/usr/bin/curl -s -O "
		break
	elif [ -x "/usr/bin/wget" ]; then
		download="/usr/bin/wget -nv"
		break
	elif [ -x "/usr/bin/fetch" ]; then
		download="/usr/bin/fetch"
		break
	elif [ $curl_attempted = 1 ]; then
		echo "Could not install curl. Cannot continue."
		exit 1
	fi

	# Made it here without finding a downloader, so try to install one
	curl_attempted = 1
	if [ -x /usr/bin/yum || -x /usr/bin/dnf ]; then
		run_ok "yum -y install curl" "Installing curl"
	elif [ -x /usr/bin/apt-get ]; then
		run_ok "apt-get update; apt-get -y -q install curl" "Installing curl"
	fi
done

printf "found %s\n" "$download"

# download()
# Use $download to download the provided filename or exit with an error.
download() {
	# XXX Check this to make sure run_ok is doing the right thing.
	# Especially make sure failure gets logged right.
	run_ok "$download $ii >> $log" "Downloading $1"
	#if "$download" "$1"
	#then
	#	success "Download of $1"
   	#return $?
	#else
	#	fatal "Failed to download $1."
	#fi
	if [ $? -ne 0 ]; then
		fatal "Failed to download $1. Cannot continue. Check your network connection and DNS settings."
	else
		return 0
	fi
}

# Only root can run this
id | grep "uid=0(" >/dev/null
if [ "$?" != "0" ]; then
	uname -a | grep -i CYGWIN >/dev/null
	if [ "$?" != "0" ]; then
		fatal "${RED}Fatal:${NORMAL} The Virtualmin install script must be run as root"
	fi
fi

# Find temp directory
if [ "$TMPDIR" = "" ]; then
	TMPDIR=/tmp
fi

# Check whether $TMPDIR is mounted noexec (everything will fail, if so)
# XXX: This check is imperfect. If $TMPDIR is a full path, but the parent dir
# is mounted noexec, this won't catch it.
TMPNOEXEC=$(grep $TMPDIR /etc/mtab | grep noexec)
if [ "$TMPNOEXEC" != "" ]; then
	echo "${RED}Fatal:${NORMAL} $TMPDIR directory is mounted noexec. Installation cannot continue."
	exit 1
fi

if [ "$tempdir" = "" ]; then
	tempdir=$TMPDIR/.virtualmin-$$
	if [ -e "$tempdir" ]; then
		rm -rf $tempdir
	fi
	mkdir $tempdir
fi

# "files" subdir for libs
mkdir $tempdir/files
srcdir=$tempdir/files
cd $srcdir

# Download spinner
$download http://software.virtualmin.com/lib/spinner
chmod +x spinner

# Setup slog so we can start keeping a proper log while also feeding output
# to the console.
echo "Loading slog logging library..."
if $download http://software.virtualmin.com/lib/slog.sh; then
	# source and configure slog
	. ./slog
else
	echo " Could not load logging library from software.virtualmin.com.  Cannot continue."
	echo " Check network connectivity, name resolution, and disk space and try again."
	exit 1
fi

# Log file
LOG_PATH=$log
# Console output level; ignore debug level messages.
LOG_LEVEL_STDOUT="INFO"
# Log file output level; catch literally everything.
LOG_LEVEL_LOG="DEBUG"

# log_fatal  calls log_error
log_fatal() {
	log_error $1
}

log_info "Started installation log in $log"

# Print out some details that we gather before logging existed
log_debug "Install mode: $mode"
log_debug "Product: Virtualmin $PRODUCT"
log_debug "Virtualmin Meta-Package list: $virtualminmeta"
log_debug "install.sh version: $VER"

# Check for a fully qualified hostname
log_info "Checking for fully qualified hostname..."
name=$(hostname -f)
if ! is_fully_qualified "$name"; then set_hostname
elif [ "$forcehostname" != "" ]; then set_hostname
fi

# Insert the serial number and password into /etc/virtualmin-license
log_info "Installing serial number and license key into /etc/virtualmin-license"
echo "SerialNumber=$SERIAL" > /etc/virtualmin-license
echo "LicenseKey=$KEY"	>> /etc/virtualmin-license
chmod 700 /etc/virtualmin-license

# Detecting the OS
# Grab the Webmin oschooser.pl script
run_ok "download http://software.virtualmin.com/lib/oschooser.pl" "Loading OS selection library"
run_ok "download http://software.virtualmin.com/lib/os_list.txt" "Loading OS list"

cd ..

# Get operating system type
if [ "$os_type" = "" ]; then
	if [ "$autoos" = "" ]; then
		autoos=1
	fi
	$perl "$srcdir/oschooser.pl" "$srcdir/os_list.txt" $tempdir/$$.os $autoos
	if [ "$?" != 0 ]; then
		exit $?
	fi
	. $tempdir/$$.os
	rm -f $tempdir/$$.os
fi
log_info "Operating system name:    $real_os_type" 
log_info "Operating system version: $real_os_version"

# FreeBSD returns a FQDN without having it set in /etc/hosts...but
# Apache doesn't use it unless it's in hosts
if [ "$os_type" = "freebsd" ]; then
	. /etc/rc.conf
	primaryiface=$(echo "$network_interfaces" | cut -d" " -f1)
	address=$(/sbin/ifconfig "$primaryiface" | grep "inet " | cut -d" " -f2)
	if ! grep "$name" /etc/hosts; then
		log_info "Detected IP $address for $primaryiface..."
		if grep "$address" /etc/hosts; then
			log_info "Entry for IP $address exists in /etc/hosts."
			log_info "Updating with new hostname."
			shortname=$(echo "$name" | cut -d"." -f1)
			sed -i "s/^$address\([\s\t]+\).*$/$address\1$name\t$shortname/" /etc/hosts
		else
			log_info "Adding new entry for hostname $name on $address to /etc/hosts."
			printf "%s\t%s\t%s\n" \
			  "$address" "$name" "$shortname" >> /etc/hosts
		fi	
	fi
fi

install_virtualmin_release () {
	# Grab virtualmin-release from the server
	log_info "Configuring package manager for $real_os_type $real_os_version..."
	case $os_type in
		rhel|fedora|amazon)
			if [ -x /usr/sbin/setenforce ]; then
				log_info "Disabling SELinux during installation..."
				if /usr/sbin/setenforce 0; then log_debug " setenforce 0 succeeded"
				else log_info "  setenforce 0 failed: $?"
				fi 
			fi
			package_type="rpm"
			deps=$rhdeps
			if type dnf; then
				install="/usr/bin/dnf -y install"
			else	
				install="/usr/bin/yum -y install"
			fi
			install_updates="$install $deps"
			download "http://${LOGIN}software.virtualmin.com/${repopath}$os_type/$os_version/$arch/virtualmin-release-latest.noarch.rpm"
			if rpm -U virtualmin-release-latest.noarch.rpm; then success
			else fatal "Installation of virtualmin-release failed: $?"
			fi
		;;
		freebsd)
			if [ ! -d /usr/ports ]; then
				if [ ! -d /usr/ports/www/apache20 ]; then
					log_info " You don't have the ports system installed.  Installation cannot  "
					log_info " complete without the ports system.  Would you like to fetch "
					log_info " ports now using portsnap?  (This may take a long time.)"
					log_info " (y/n)"
					if ! yesno; then 
						log_info " Exiting.  Please install the ports system using portsnap, and"
						log_info " run this script again."
						exit
					fi
					portsnap fetch; portsnap extract
				fi
			fi
			package_type="tar"
			deps=$pkgdeps
			# Holy crap!  FreeBSD pkg_add cannot run non-interactively...it leaves
			# packages in a completely unusable state.  FreeBSD users will just have
			# to answer a lot of questions during installation.
			install="pkg_add -r"
			echo "pkg_add cannot safely be run without user interaction, so don't go anywhere."
			echo "you'll need to answer some questions."
			install_updates="echo Skipping checking for updates..."
		;;
		debian | ubuntu)
			package_type="deb"
			if [ "$os_type" = "ubuntu" ]; then
				deps=$ubudeps
				case $os_version in
					12.04*)
						repos="virtualmin-precise virtualmin-universal"
					;;
					14.04*)
						repos="virtualmin-trusty virtualmin-universal"
					;;
					16.04*)
						repos="virtualmin-xenial virtualmin-univseral"
				esac
			else
				deps=$debdeps
				case $os_version in
					6.0*)
						repos="virtualmin-squeeze virtualmin-universal"
					;;
					7*)
						repos="virtualmin-wheezy virtualmin-universal"
					;;
					8*)
						repos="virtualmin-jessie virtualmin-universal"
					;;
				esac
			fi
			# Make sure universe repos are available
			# XXX Test to make sure this run_ok syntax works as expected (with single quotes inside double)
			run_ok "sed -ie 's/#*[ ]*deb \(.*\) universe$/deb \1 universe/' /etc/apt/sources.list" \
				"Enabling universe repositories, if not already available"
			# XXX Is this still enabled by default on Debian/Ubuntu systems?
			run_ok "sed -ie 's/^deb cdrom:/#deb cdrom:/' /etc/apt/sources.list" "Disabling cdrom: repositories"
			run_ok "apt-get update" "Updating apt-get metadata"
			install="/usr/bin/apt-get --config-file apt.conf.noninteractive -y --force-yes install"
			export DEBIAN_FRONTEND=noninteractive
			install_updates="$install $deps"
			run_ok $(apt-get clean) "Cleaning out old metadata"
			# Get the noninteractive apt-get configuration file (this is 
			# stupid... -y ought to do all of this).
			download "http://software.virtualmin.com/lib/apt.conf.noninteractive"
			sed -i "s/\(deb[[:space:]]file.*\)/#\1/" /etc/apt/sources.list
			for repo in $repos; do
				echo "deb http://${LOGIN}software.virtualmin.com/${repopath}$os_type/ $repo main" >> /etc/apt/sources.list
			done
			# Install our keys
			log_info "Installing Webmin and Virtualmin package signing keys..."
			download "http://software.virtualmin.com/lib/RPM-GPG-KEY-virtualmin"
			download "http://software.virtualmin.com/lib/RPM-GPG-KEY-webmin"
			log_info $(apt-key add RPM-GPG-KEY-virtualmin)
			log_info $(apt-key add RPM-GPG-KEY-webmin)
			log_info $(apt-get update)
			log_info "Removing Debian standard Webmin package, if they exist..."
			log_info "Removing Debian apache packages..."
			log_debug $(apt-get -y --purge remove webmin-core apache apache2)
		;;
		*)
			log_info " Your OS is not currently supported by this installer."
			log_info " You can probably run Virtualmin Professional on your system, anyway,"
			log_info " but you'll have to install it using the manual installation process."
			log_info ""
			exit 1
		;;
	esac

	return 0
}

# Install Functions
install_with_apt () {
	log_info "Installing Virtualmin and all related packages now using the command:"
	log_info "$install $virtualminmeta"

	if ! runner "$install $virtualminmeta"; then
		log_warn "apt-get seems to have failed. Are you sure your OS and version is supported?"
		log_warn "http://www.virtualmin.com/os-support"
		fatal "Installation failed: $?"
	fi

        # Disable some things by default
        update-rc.d mailman disable
        service mailman stop
        update-rc.d postgresql-8.3 disable
        service postgresql-8.3 stop
        update-rc.d postgresql-8.4 disable
        service postgresql-8.4 stop
        update-rc.d spamassassin disable
        service spamassassin stop
        update-rc.d clamav-daemon disable
        service clamav-daemon stop


	log_info "Installing Virtualmin modules:"
	log_info "$install webmin-virtual-server webmin-virtualmin-awstats webmin-virtualmin-htpasswd"

        if ! runner "$install webmin-virtual-server webmin-virtualmin-awstats webmin-virtualmin-htpasswd"; then
                log_warn "apt-get seems to have failed. Are you sure your OS and version is supported?"
                log_warn "http://www.virtualmin.com/os-support"
                fatal "Installation failed: $?"
        fi

        # Make sure the time is set properly
        /usr/sbin/ntpdate-debian

	return 0
}

install_with_yum () {
	log_info "Installing Virtualmin and all related packages now using the command:"
	log_info "yum clean all"
	yum clean all
	log_info "yum -y -d 2 install $virtualminmeta"

	if ! runner "yum -y -d 2 install $virtualminmeta"; then
		fatal "Installation failed: $?"
	fi

	return 0
}

install_with_tar () {
	# XXX This is FreeBSD specific at the moment.  Needs to be smarter for other BSDs
	# or merging the solaris standalone installer into this script.  It'll probably
	# be rewritten in perl by then anyway.
	log_info "Installing Webmin..."
	# Try to make Webmin not disown Apache on install
	ln -s /usr/local/etc/apache22 /usr/local/etc/apache
	# Install Webmin
	if ! download http://${LOGIN}software.virtualmin.com/${repopath}wbm/webmin-current.tar.gz; then
		fatal "Retrieving Webmin from software.virtualmin.com failed."
	fi
	if ! gunzip -c webmin-current.tar.gz | tar xf -; then
		fatal "Extracting Webmin from archive failed."
	fi
	rm webmin-current.tar.gz
	cd webmin-[0-9]*
	config_dir=/usr/local/etc/webmin
	webmin_config_dir=$config_dir
	var_dir=/var/webmin
	autoos=3
	port=10000
	login=root
	crypt=x
	ssl=1
	atboot=1
	perl=/usr/bin/perl
	theme=authentic-theme
	export config_dir var_dir autoos port login crypt ssl atboot perl theme
	log_info "Installing Webmin..."
	runner "./setup.sh /usr/local/webmin"
	cd $tempdir
	rm -rf webmin-[0-9]*

  	# Install Usermin
  	log_info "Installing Usermin..."
 	if ! download http://${LOGIN}software.virtualmin.com/${repopath}wbm/usermin-current.tar.gz; then
    		fatal "Retrieving Usermin from software.virtualmin.com failed."
  	fi
  	if ! gunzip -c usermin-current.tar.gz | tar xf -; then
		fatal "Extracting Usermin from archive failed."
	fi
	rm usermin-current.tar.gz
	cd usermin-[0-9]*
	config_dir=/usr/local/etc/usermin
	var_dir=/var/usermin
	autoos=3
	port=20000
	login=root
	crypt=x
	ssl=1
	atboot=1
	perl=/usr/bin/perl
	theme=authentic-theme
	export config_dir var_dir autoos port login crypt ssl atboot perl theme
	log_info "Installing Usermin..."
	runner "./setup.sh /usr/local/usermin"
	cd $tempdir
	rm -rf usermin-[0-9]*

	# Install Virtulmin-specific modules and themes, as defined in updates.txt
	log_info "Installing Virtualmin modules and themes..."
	cd $tempdir
	$download http://${LOGIN}software.virtualmin.com/${repopath}wbm/updates.txt
	for modpath in $(cut -f 3 updates.txt); do
	  modfile=$(basename "$modpath")
		$download "http://${LOGIN}software.virtualmin.com/$modpath"
		if [ "$?" != "0" ]; then
			log_info "Download of Webmin module from $modpath failed"
		fi
		/usr/local/webmin/install-module.pl "$tempdir/$modfile" /usr/local/etc/webmin >> $log
		if [ "$?" != "0" ]; then
			log_info "Installation of Webmin module from $modpath failed"
		fi
		if [ -r $tempdir/virtual-server-theme-*.wbt.gz ]; then
			/usr/local/usermin/install-module.pl $tempdir/$modfile /usr/local/etc/webmin >> $log
		fi
		rm -f "$tempdir/$modfile"
	done

	# Configure Webmin to use updates.txt
	log_info "Configuring Webmin to use Virtualmin updates service..."
	echo "upsource=http://software.virtualmin.com/${repopath}wbm/updates.txt	http://www.webmin.com/updates/updates.txt" >>$webmin_config_dir/webmin/config
	if [ -n "$LOGIN" ]; then
		echo "upuser=$SERIAL" >>$webmin_config_dir/webmin/config
		echo "uppass=$KEY" >>$webmin_config_dir/webmin/config
	fi
	echo "upthird=1" >>$webmin_config_dir/webmin/config
	echo "upshow=1" >>$webmin_config_dir/webmin/config

	# Configure Webmin to know where apache22 lives
	log_info "Configuring Webmin Apache module..."
	sed -i -e "s/apache\//apache22\//" $webmin_config_dir/apache/config
	# Tell Webmin about a great wrongness in the force
	if grep pid_file $webmin_config_dir/apache/config; then
		sed -i -e "s/pid_file=.*/pid_file=\/var\/run\/httpd.pid/" $webmin_config_dir/apache/config
	else
		echo "pid_file=/var/run/httpd.pid" >> $webmin_config_dir/apache/config
	fi
	sed -i -e "s/httpd_dir=.*/httpd_dir=\/usr\/local/" $webmin_config_dir/apache/config
	setconfig "stop_cmd=/usr/local/etc/rc.d/apache22 stop" $webmin_config_dir/apache/config
	setconfig "start_cmd=/usr/local/etc/rc.d/apache22 start" $webmin_config_dir/apache/config
	setconfig "graceful_cmd=/usr/local/etc/rc.d/apache22 reload" $webmin_config_dir/apache/config
	setconfig "apply_cmd=/usr/local/etc/rc.d/apache22 restart" $webmin_config_dir/apache/config
	
	# Configure Webmin to know how to stop and start MySQL
	setconfig "start_cmd=/usr/local/etc/rc.d/mysql-server start" $webmin_config_dir/mysql/config
	setconfig "stop_cmd=/usr/local/etc/rc.d/mysql-server stop" $webmin_config_dir/mysql/config

	# Configure Webmin to know Usermin lives in /usr/local/etc/usermin
	sed -i -e "s/usermin_dir=.*/usermin_dir=\/usr\/local\/etc\/usermin/" $webmin_config_dir/usermin/config

	# Add environment settings so that API scripts work
	if grep -qv WEBMIN_CONFIG /etc/profile; then 
		echo "export WEBMIN_CONFIG=/usr/local/etc/webmin" >>/etc/profile
	fi
	if grep -qv WEBMIN_CONFIG /etc/csh.cshrc; then
		echo "setenv WEBMIN_CONFIG '/usr/local/etc/webmin'" >>/etc/csh.cshrc
	fi

	# Dovecot won't start with our default config without an SSL cert
	testmkdir /etc/ssl/certs/; testmkdir /etc/ssl/private
	openssl x509 -in /usr/local/webmin/miniserv.pem > /etc/ssl/certs/dovecot.pem
	openssl rsa -in /usr/local/webmin/miniserv.pem > /etc/ssl/private/dovecot.pem

	# It's possible to get here without address being defined
	. /etc/rc.conf
	primaryiface=${primaryiface:=$(echo "$network_interfaces" | cut -d" " -f1)}
	address=${address:=$(/sbin/ifconfig "$primaryiface" | grep "inet " | cut -d" " -f2)}
	# Tons of syntax errors in the default Apache configuration files.
	# Seriously?  Syntax errors?
	vhostsconf=/usr/local/etc/apache22/extra/httpd-vhosts.conf
	sed -i -e "s/NameVirtualHost \*:80/NameVirtualHost $address:80/" $vhostsconf
	sed -i -e "s/VirtualHost \*:80/VirtualHost $address:80/" $vhostsconf
	sed -i -e "s#CustomLog \"/var/log/dummy-host.example.com-access_log common\"#CustomLog \"/var/log/dummy-host.example.com-access_log\" common#" $vhostsconf
	sed -i -e "s#CustomLog \"/var/log/dummy-host2.example.com-access_log common\"#CustomLog \"/var/log/dummy-host2.example.com-access_log\" common#" $vhostsconf
	sed -i -e "s#/usr/local/docs/dummy-host.example.com#/usr/local/www/apache22/data#" $vhostsconf
	sed -i -e "s#/usr/local/docs/dummy-host2.example.com#/usr/local/www/apache22/data#" $vhostsconf
	# mod_dav loaded twice.  No idea why, but luckily, they have slightly
	# different spacing, so we can strip out just one of 'em.
	sed -i -e "s#LoadModule dav_module         libexec/apache22/mod_dav.so##" /usr/local/etc/apache22/httpd.conf

	# Dummy SSL cert, if none exists
	testcp /etc/ssl/certs/dovecot.pem /usr/local/etc/apache22/server.crt
	testcp /etc/ssl/private/dovecot.pem /usr/local/etc/apache22/server.key

	# PostgreSQL needs to be initialized
	log_info "Initializing postgresql database..."
	runner "/usr/local/etc/rc.d/postgresql initdb"

	# Webmin <=1.411 doesn't know the right paths
	setconfig "stop_cmd=/usr/local/etc/rc.d/postgresql stop" $webmin_config_dir/postgresql/config
	setconfig "start_cmd=/usr/local/etc/rc.d/postgresql start" $webmin_config_dir/postgresql/config
	setconfig "setup_cmd=/usr/local/etc/rc.d/postgresql initdb" $webmin_config_dir/postgresql/config


	# Virtualmin configuration
	export WEBMIN_CONFIG=/usr/local/etc/webmin
	$download http://software.virtualmin.com/lib/virtualmin-base-standalone.pl
	perl virtualmin-base-standalone.pl install>>$log

	# Virtualmin can't guess the interface on FreeBSD (and neither can this
	# script, but it pretends)
	log_info "Detecting network interface on FreeBSD is unreliable.  Be sure to check the"
	log_info "interface in module configuration before creating any virtual servers."
	sed -i -e "s/iface=.*/iface=$primaryiface/" $webmin_config_dir/virtual-server/config

	return 0
}

install_deps_the_hard_way () {
	case $os_type in
		freebsd)
			portsenv="BATCH=YES DISABLE_VULNERABILITIES=YES"
			for i in $portsenv; do
				export $i
			done

			previousdir=$(pwd)
			log_info "Installing Apache from ports..."
			apacheopts="WITH_AUTH_MODULES=yes WITH_PROXY_MODULES=yes WITH_SSL_MODULES=yes WITH_SUEXEC=yes SUEXEC_DOCROOT=/home WITH_BERKELEYDB=db42"
			cd /usr/ports/www/apache22
			make "$apacheopts" install
			# Load accept filter into kernel...no idea why, but Apache issues
			# warnings without it.
			if ! grep -qv 'accf_http_load=”YES”' /boot/loader.conf; then
				echo 'accf_http_load=”YES”' >>/boot/loader.conf
				kldload accf_http
			fi

			log_info "Installing mod_fcgid using ports..."
			cd /usr/ports/www/mod_fcgid
			make APACHE_VERSION=22 install

			log_info "Installing Subversion using ports..."
			export WITH_MOD_DAV_SVN=yes
			export WITH_APACHE2_APR=yes
			cd /usr/ports/devel/subversion
			make install

			# cyrus-sasl2 pkg doesn't have passwd auth, so build port 
			log_info "Installing cyrus-sasl2-saslauthd from ports..."
			cd /usr/ports/security/cyrus-sasl2-saslauthd
			make install

			log_info "Installing postfix from ports..."
			export WITH_SASL2=yes
			cd /usr/ports/mail/postfix23
			make install

			cd "$previousdir"
			log_info "Installing dependencies using command: "
			log_info " for i in $deps; do $install \$i; done"	
			for i in $deps; do $install "$i">>$log; done
			if [ "$?" != "0" ]; then
				log_warn "Something went wrong during installation: $?"
				log_warn "FreeBSD pkd_add cannot reliably detect failures, or successes,"
				log_warn "so we're going to proceed as if nothing bad happened."
				log_warn "This may lead to problems later in the process, and"
				log_warn "some packages may not have installed successfully."
				log_warn "You may wish to check $log for details."
			else
				success
			fi
			
			# FreeBSD packages aren't very package-like
			log_info "Copying default my.cnf and initializing database..."
			testcp /usr/local/share/mysql/my-medium.cnf /etc/my.cnf
			testmkdir /var/db/mysql
			log_info $(/usr/local/etc/rc.d/mysql-server start)
			
			# SpamAssassin needs a config file
			testcp /usr/local/etc/mail/spamassassin/local.cf.sample /usr/local/etc/mail/spamassassin/local.cf
			
			# Clam needs fresh database
			log_info "Initializing the clamav database.  This may take a long time..."
			freshclam

			# awstats
			testmkdir /usr/local/etc/awstats
			testcp /usr/local/www/awstats/cgi-bin/awstats.model.conf /usr/local/etc/awstats/awstats.model.conf

			# www user needs a shell to run mailman commands
			chpass -s /bin/sh www

			# procmail-wrapper download and install
			log_info "Installing procmail-wrapper."
			download "http://${LOGIN}software.virtualmin.com/${repopath}$os_type/$os_version/$arch/procmail-wrapper"
			mv procmail-wrapper /usr/bin
			chmod 6755 /usr/bin/procmail-wrapper
			if [ ! -e /usr/bin/procmail ]; then
			    ln -s /usr/local/bin/procmail /usr/bin/procmail
			fi

			return 0
		;;
		*)
			log_info "Installing dependencies using command: $install $deps"
			if ! runner "$install $deps"; then
				fatal "Something went wrong during installation: $?"
			fi
			return 0
		;;
	esac
}

install_virtualmin () {
	case $package_type in
		rpm)
			install_with_yum
		;;
		deb)
			install_with_apt
		;;
		*)
			install_with_tar
		;;
	esac
	return 0
}

# virtualmin-release only exists for one platform...but it's as good a function
# name as any, I guess.  Should just be "setup_repositories" or something.
install_virtualmin_release
# We have to use $install to pre-install all deps, because some systems don't
# cooperate with our repositories.
if [ "$mode" = "full" ]; then
	install_deps_the_hard_way
fi

install_virtualmin

# We want to make sure we're running our version of packages if we have
# our own version.  There's no good way to do this, but we'll 
run_ok "$install_updates" "Installing updates to Virtualmin-related packages"

# Functions that are used in the OS specific modifications section
disable_selinux () {
	seconfigfiles="/etc/selinux/config /etc/sysconfig/selinux"
	for i in $seconfigfiles; do
		if [ -e "$i" ]; then
			sed -i "s/SELINUX=.*/SELINUX=disabled/" "$i"
		fi
	done
}

# Changes that are specific to OS
case $os_type in
	"fedora" | "centos" | "rhel" | "amazon" )
		disable_selinux
	;;
esac

# Run sa-update if installed, to ensure spamassassin rules are recent
if type sa-update > /dev/null; then
  run_ok "sa-update" "Updating SpamAssassin rules with sa-update"
fi

exit 0
