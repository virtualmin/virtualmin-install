#!/bin/sh
# virtualmin-install.sh
# Copyright 2005-2006 Virtualmin, Inc.
# Simple script to grab the virtualmin-release and virtualmin-base packages.
# The packages do most of the hard work, so this script can be small-ish and 
# lazy-ish.

# WARNING: Anything not listed in the currently supported systems list is not
# going to work, despite the fact that you might see code that detects your
# OS and acts on it.  If it isn't in the list, the code is not complete and
# will not work.  Don't even bother trying it.  Trust me.

# Currently supported systems:
# Fedora Core 3, 4 and 5 on i386 and x86_64
# CentOS and RHEL 3 and 4 on i486 and x86_64
# SuSE 9.3 and OpenSUSE 10.0 on i586

LANG=
export LANG

SERIAL=ZEZZZZZE
KEY=sdfru8eu38jjdf
VER=EA2g
ARCH=`uname -i`
vmpackages="usermin webmin wbm-virtualmin-awstats wbm-virtualmin-dav wbm-virtualmin-dav wbm-virtualmin-htpasswd wbm-virtualmin-svn wbm-virtual-server wbt-virtualmin-nuvola* ust-virtualmin-nuvola* ust-virtual-server-theme wbt-virtual-server-theme"
deps=
# Red Hat-based systems 
rhdeps="httpd-devel postfix bind spamassassin procmail perl perl-DBD-Pg perl-DBD-MySQL quota iptables openssl python mailman subversion ruby rdoc ri mysql mysql-server postgresql postgresql-server rh-postgresql rh-postgresql-server logrotate webalizer php php-domxl php-gd php-imap php-mysql php-odbc php-pear php-pgsql php-snmp php-xmlrpc php-mbstring mod_perl mod_python cyrus-sasl dovecot spamassassin mod_dav_svn cyrus-sasl-gssapi mod_fastcgi mod_ssl"
# SUSE systems (SUSE and OpenSUSE)
yastdeps="webmin usermin postfix bind perl-spamassassin spamassassin procmail perl-DBI perl-DBD-Pg perl-DBD-mysql quota openssl mailman subversion ruby mysql mysql-Max mysql-administrator mysql-client mysql-shared postgresql postgresql-pl postgresql-libs postgresql-server webalizer apache2 apache2-devel apache2-mod_fastcgi apache2-mod_perl apache2-mod_python apache2-mod_php4 apache2-mod_ruby apache2-worker apache2-prefork clamav awstats dovecot cyrus-sasl cyrus-sasl-gssapi proftpd php4 php4-domxml php4-gd php4-imap php4-mysql php4-mbstring php4-pgsql php4-pear php4-session"
# Mandrake/Mandriva
urpmideps="apache2 apache2-common apache2-manual apache2-metuxmpm apache2-mod_dav apache2-mod_fastcgi apache2-mod_ldap apache2-mod_perl apache2-mod_php apache2-mod_proxy apache2-mod_suexec apache2-mod_ssl apache2-modules apache2-peruser apache2-worker clamav clamav-db clamd bind bind-utils caching-nameserver cyrus-sasl postfix postfix-ldap postgresql postgresql-contrib postgresql-docs postgresql-pl postgresql-plperl postgresql-server proftpd proftpd-anonymous quota perl-Net_SSLeay perl-DBI perl-DBD-Pg perl-DBD-mysql spamassassin perl-Mail-SpamAssassin mailman subversion subversion-server MySQL MySQL-common MySQL-client openssl ruby usermin webmin webalizer awstats dovecot"
# Debian-based systems (Ubuntu and Debian)
debdeps="postfix postfix-tls bind9 spamassassin spamc procmail perl libnet-ssleay-perl libpg-perl libdbd-pg-perl libdbd-mysql-perl quota iptables openssl python mailman subversion ruby irb rdoc ri mysql mysql-server mysql-client mysql-admin-common mysql-common postgresql postgresql-client logrotate awstats webalizer php4 clamav awstats dovecot cyrus-sasl proftpd proftpd-common proftpd-doc proftpd-ldap proftpd-mysql proftpd-pgsql"
# Ports-based systems (FreeBSD, NetBSD, OpenBSD)
portsdeps="postfix bind9 p5-Mail-SpamAssassin procmail perl p5-Class-DBI-Pg p5-Class-DBI-mysql setquota openssl python mailman subversion ruby irb rdoc ri mysql-client mysql-server postgresql-client postgresql-server postgresql-contrib logrotate awstats webalizer php4 clamav dovecot cyrus-sasl"
# Gentoo
portagedeps="postfix bind spamassassin procmail perl DBD-Pg DBD-mysql quota openssl python mailman subversion ruby irb rdoc mysql postgresql logrotate awstats webalizer php Net-SSLeay iptables clamav dovecot"

# == Some simple functions ==
threelines () {
	echo; echo; echo
}

yesno () {
  while read line; do
    case $line in
      y|Y|Yes|YES|yes|yES|yEs|YeS|yeS) return 0
      ;;
      n|N|No|NO|no|nO) return 1
      ;;
      *)
        printf "\nPlease enter y or n: "
        continue
      ;;
    esac
  done
}

fatal () {
	echo
	logger_fatal "Fatal Error Occurred: $1"
	logger_fatal "Cannot continue installation."
	logger_fatal "Attempting to remove virtualmin repository configuration, so the installation can be "
	logger_fatal "re-attempted after any problems have been resolved."
	remove_virtualmin_release
	logger_fatal "If you are unsure of what went wrong, you may wish to review the log"
	logger_fatal "in /root/virtualmin-install.log."
	exit
}

remove_virtualmin_release () {
	case $os_type in
		"fedora" | "centos" |	"rhel"	)	rpm -e virtualmin-release;;
		"suse"	)
			vmsrcs=`y2pmsh source -s | grep "virtualmin" | grep "^[[:digit:]]" | cut -d ":" -f 1`
			y2pmsh source -R $vmsrcs
			;;
		"mandriva" )
			urpmi.removemedia virtualmin
			urpmi.removemedia virtualmin-universal
			rpm -e virtualmin-release
      ;;
		"debian" )
			;;
	esac
}

detect_ip() {
  primaryaddr=`/sbin/ifconfig eth0|grep 'inet addr'|cut -d: -f2|cut -d" " -f1`
  if [ $primaryaddr ]; then
    logger_info "Primary address detected as $primaryaddr"
    return $primaryaddr
  else
    logger_info "Unable to determine IP address of primary interface."
    echo "Please enter the name of your primary network interface: "
    read primaryinterface
    primaryaddr=`/sbin/ifconfig $primaryinterface|grep 'inet addr'|cut -d: -f2|cut -d" " -f1`
    if [ $primaryaddr ]; then
      logger_info "Primary address detected as $primaryaddr"
      return $primaryaddr
    else
      logger_info "Unable to determine IP address of selected interface.  Cannot continue."
      exit 1
    fi
}

set_hostname () {
  i=0
  while [ $i -eq 0 ]; do
    printf "Please enter a fully qualified hostname (for example, virtualmin.com): "
    read line
    if [ ! is_fully_qualified($line) ]; then
      logger_info "Hostname $line is not fully qualified."
    else
      hostname $line
      address=detect_ip
      if [ `grep $address /etc/hosts` ]; then
        logger_info "Entry for IP $address exists in /etc/hosts.  Updating with new hostname."
        shortname=`echo $line | cut -d"." -f1`
        sed -i "s/^$address\([\s\t]+\).*$/$address\1$line\t$shortname/" /etc/hosts
      else
        logger_info "Adding new entry for hostname $line on $address to /etc/hosts."
        echo "$address\t$line\t$shortname" >> /etc/hosts
      fi
      i=1
    fi
  done
}
  
is_fully_qualified () {
  case $1 in
  localhost.localdomain)
    logger_info "Hostname cannot be localhost.localdomain."
    return 1
  ;;
  *.*)
    logger_info "Hostname OK: fully qualified as $1"
    return 0
  ;;
  esac
  logger_info "Hostname $name is not fully qualified."
  return 1
}

success () {
	logger_info "Succeeded."
}

# == End of functions ==


cat <<EOF
***********************************************************************
*   Welcome to the Virtualmin Professional installer, version $VER    *
***********************************************************************

 WARNING: This is an Early Adopter release.

 The installation is quite stable and functional when run on a freshly
 installed supported Operating System, but upgrades from Virtualmin GPL
 systems, or systems that already have Apache VirtualHost directives or
 mail users, will very likely run into numerous problems.  Please read
 the Virtualmin and Early Adopter FAQs before proceeding if your system
 is not a freshly installed and supported OS.

 The systems currently supported by our install.sh are:

 Fedora Core 3-5 on i386 and x86_64
 CentOS and RHEL 3 and 4 on i386 and x86_64
 SUSE 9.3 and OpenSUSE 10.0 on i386
 Mandriva 10.2 (also known as 2006.0 and 2006.1) on i386

 If your OS is not listed above, this script will fail (and attempting
 to run it on an unsupported OS is not recommended, or...supported).
 
EOF
printf " Continue? (y/n) "
if yesno
then continue
else exit 0
fi
threelines
if [ -x /usr/libexec/webmin/virtual-server ]; then
  oldmodule="/usr/libexec/webmin/virtual-server"
else if [ -x /usr/share/webmin/virtual-server ]; then
  oldmodule="/usr/share/webmin/virtual-server"
fi
if [ $oldmodule ]; then
cat <<EOF
 It appears you already have some version of the Virtualmin virtual-server
 module installed.  The package that will be installed during the Virtualmin
 Professional installation won't overwrite an existing installation, and so
 installation will fail if the old module remains in place.

 I can move your old installation of the Virtualmin module out of the way,
 which will allow the new Virtualmin to be installed.  This process will not
 delete your existing Virtualmin domains, if any.  It usually also allows
 for a reasonably clean upgrade from Virtualmin GPL to Virtualmin Professional.

 However, if you did not backup your server immediately before you began this
 installation, I strongly recommend you exit now (enter "n") and do so.  There
 are many things that can go wrong during an upgrade, and while we won't be 
 doing very many things that aren't easily reverted, there is still potential
 for data loss.

 If it is OK for me to move your current installation out of the way, so that
 installation can proceed, enter "y" here.

EOF
printf " Move existing Virtualmin module and proceed with installation? (y/n) "
if yesno
then
	mkdir /root/virtualmin-install-backup-files
  mv $oldmodule /root/virtualmin-install-backup-files
else
  echo " Installation interrupted.  If you have any questions about upgrading,"
  echo " please file an issue in the Customer Issues tracker or post in the "
  echo " support forums at Virtualmin.com."
  exit
fi
threelines
get_mode () {
cat <<EOF
 FULL or MINIMAL INSTALLATION
 It is possible to upgrade an existing Virtualmin GPL installation
 or install without replacing existing mail/web/DNS configuration
 or packages.  This mode of installation is called the minimal mode
 because only Webmin, Usermin and the Virtualmin-related modules and
 themes are installed.  The minimal mode will not modify your
 existing configuration.  The full install is recommended if
 this system is a fresh install of the OS.

EOF
printf " Perform a full installation? (y/n) "
if yesno
then mode=full
else mode=minimal
fi
threelines
echo "Installation type: $mode"
sleep 3
threelines
}
mode="full"
virtualminmeta="virtualmin-base"
#get_mode
# If minimal, we don't install any extra packages, or perform any configuration
if [ "$mode" = "minimal" ]; then
	rhdeps=yastdeps=debdeps=portagedeps=portsdeps=""
	virtualminmeta=$vmpackages
fi

# Check for wget or curl
printf "Checking for curl or wget..."
if [ -x "/usr/bin/curl" ]; then
	download="/usr/bin/curl -O"
elif [ -x "/usr/bin/wget" ]; then
	download="/usr/bin/wget"
else
	echo "No web download program available: Please install curl or wget"
	echo "and try again."
	exit 1
fi
printf "found $download\n"

# Checking for perl
printf "Checking for perl..."
if [ -x "/usr/bin/perl" ]; then
	perl="/usr/bin/perl"
elif [ -x "/usr/local/bin/perl" ]; then
	perl="/usr/local/bin/perl"
else
	echo "Perl was not found on your system: Please install perl and try again"
	exit 1
fi
printf "found $perl\n"

# Only root can run this
id | grep "uid=0(" >/dev/null
if [ "$?" != "0" ]; then
	uname -a | grep -i CYGWIN >/dev/null
	if [ "$?" != "0" ]; then
		echo "Fatal Error: The Virtualmin install script must be run as root"
		threelines
		exit 1
	fi
fi

# Find temp directory
if [ "$tempdir" = "" ]; then
	tempdir=/tmp/.virtualmin-$$
	if [ -e "/tmp/.virtualmin*" ]; then
		rm -rf /tmp/.virtualmin*
	fi
	mkdir $tempdir
fi

# "files" subdir for libs
mkdir $tempdir/files
srcdir=$tempdir/files
cd $srcdir

# Setup log4sh so we can start keeping a proper log while also feeding output
# to the console.
echo "Loading log4sh logging library..."
if $download http://software.virtualmin.com/lib/log4sh
then 
	# source log4sh (disabling properties file warning)
	LOG4SH_CONFIGURATION="none" . ./log4sh
	continue
else
	echo " Could not load logging library from software.virtualmin.com.  Cannot continue."
	echo " We're not just stopping because we don't have a logging library--this probably"
	echo " indicates much larger problems that will prevent successful installation anyway."
	echo " Check network connectivity, name resolution and disk space and try again."
	exit 1
fi

# Setup log4sh properties
# Console output
logger_setLevel INFO
# Debug log
logger_addAppender virtualmin
appender_setAppenderType virtualmin FileAppender
appender_setAppenderFile virtualmin /root/virtualmin-install.log
appender_setLevel virtualmin ALL
appender_setLayout virtualmin PatternLayout

logger_info "Started installation log in virtualmin-install.log"

# Print out some details that we gather before logging existed
logger_debug "Install mode: $mode"
logger_debug "Virtualmin Meta-Packages list: $virtualminmeta"

# Check for a fully qualified hostname
logger_info "Checking for fully qualified hostname..."
name=`hostname -f`
if [ is_fully_qualified $name ]; then continue
else set_hostname

# Insert the serial number and password into /etc/virtualmin-license
logger_info "Installing serial number and license key into /etc/virtualmin-license"
echo "SerialNumber=$SERIAL" > /etc/virtualmin-license
echo "LicenseKey=$KEY"	>> /etc/virtualmin-license
chmod 700 /etc/virtualmin-license

# Detecting the OS
# Grab the Webmin oschooser.pl script
logger_info "Loading OS selection library..."
if $download http://software.virtualmin.com/lib/oschooser.pl
then 
	success
	continue
else
	fatal "Could not load OS selection library from software.virtualmin.com.  Cannot continue."
fi
if $download http://software.virtualmin.com/lib/os_list.txt
then continue
else
	fatal "Could not load OS list from software.virtualmin.com.  Cannot continue."
fi

cd ..

# Get operating system type
logger_info "***********************************************************************"  
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
logger_info "Operating system name:    $real_os_type"
logger_info "Operating system version: $real_os_version"
logger_info "***********************************************************************"

install_virtualmin_release () {
	# Grab virtualmin-release from the server
	logger_info "Installing virtualmin-release package for $real_os_type $real_os_version..."
  case $os_type in
		fedora|rhel)
      if [ -x /usr/sbin/setenforce ]; then
			  logger_info "Disabling SELinux during installation..."
			  if [ `/usr/sbin/setenforce 0` ]; then logger_debug " setenforce 0 succeeded"
        else logger_info "  setenforce 0 failed: $?"
        fi
      fi
			package_type="rpm"
			deps=$rhdeps
			if [ -e /usr/bin/yum ]; then
        # We have yum, so we'll assume we're able to install all deps with it
				install="/usr/bin/yum -y install"
				continue
			else
        # Red Hat doesn't have yum for OS updates, so we'll get those with up2date
				install="/usr/bin/up2date --nox"
				rpm --import /usr/share/rhn/RPM-GPG-KEY
				# Install yum, which makes installing and upgrading our packages easier
 				if $download http://$SERIAL:$KEY@software.virtualmin.com/$os_type/$os_version/$arch/yum-latest.noarch.rpm
				then
					logger_info "yum not found, installing yum from software.virtualmin.com..."
					if [ `rpm -U yum-latest.noarch.rpm` ]; then sucess
          else fatal "Installation of yum failed: $?"
          fi
  				continue
  			else
    			fatal "Failed to download yum package for $os_type.  Cannot continue."
				fi
			fi
			if $download http://$SERIAL:$KEY@software.virtualmin.com/$os_type/$os_version/$arch/virtualmin-release-latest.noarch.rpm
			then
				if [ `rpm -U virtualmin-release-latest.noarch.rpm` ]; then sucess
				else fatal "Installation of virtualmin-release failed: $?"
        fi 
			else
				fatal "Failed to download virtualmin-release package for $os_type.  Cannot continue."
			fi
		;;
		suse)
			# No release for suse.  Their RPM locks when we try to import keys...
			package_type="rpm"
			deps=$yastdeps
      install="/sbin/yast -i"
			# SUSE uses i586 for x86 binary RPMs instead of i386
			if [ "$arch" = "i386" ]
			then cputype="i586"
			else cputype="x86_64"
			fi
			if yast -i y2pmsh; then
				continue
			else
				fatal "Failed to install y2pmsh package.  Cannot continue."
			fi
			if y2pmsh source -a http://$SERIAL:$KEY@software.virtualmin.com/$os_type/$os_version/$cputype; then
				continue
			else
				fatal "Unable to add yast2 installation source."
			fi
			if y2pmsh source -a http://$SERIAL:$KEY@software.virtualmin.com/universal; then
				continue
			else
				fatal "Unable to add yast2 installation source."
    	fi
		;;
		mandriva)
			# No release for mandriva either...
			package_type="rpm"
			deps=$urpmideps
      install="/usr/sbin/urpmi"
      if urpmi.update -a; then
        continue
      else fatal "urpmi.update failed with $?.  This installation script requires a functional urpmi"
			# Mandriva uses i586 for x86 binary RPMs instead of i386--uname is also utterly broken
			if [[ "$arch" = "i386" || "$arch" = "unknown" ]]
      then cputype="i586"
      else cputype="x86_64"
      fi
			if urpmi.addmedia virtualmin-universal http://$SERIAL:$KEY@software.virtualmin.com/universal; then
				continue
			else fatal "Failed to add urpmi source for virtualmin-universal.  Cannot continue."
			fi
			if urpmi.addmedia virtualmin http://$SERIAL:$KEY@software.virtualmin.com/$os_type/$os_version/$cputype; then
				continue
      else fatal "Failed to add urpmi source for virtualmin.  Cannot continue."
			fi
			# Install some keys
			if $download http://$SERIAL:$KEY@software.virtualmin.com/$os_type/$os_version/$cputype/virtualmin-release-latest.noarch.rpm
      then
        if [ `rpm -Uvh virtualmin-release-latest.noarch.rpm` ]; then success
        else fatal "Failed to install virtualmin-release package."
        fi
			  rpm --import /etc/RPM-GPG-KEYS/RPM-GPG-KEY-webmin
				rpm --import /etc/RPM-GPG-KEYS/RPM-GPG-KEY-virtualmin
        success
      else
        fatal "Failed to download virtualmin-release package for $os_type.  Cannot continue."
      fi
		;;
		freebsd)
			package_type="tar"
			deps=$portsdeps
			if $download http://$SERIAL:$KEY@software.virtualmin.com/$os_type/$arch/virtualmin-release-latest.tar.gz
			then continue
			else
				fatal "Failed to download virtualmin-release package for $os_type.  Cannot continue."
			fi
		;;
		gentoo)
			package_type="ebuild"
  		deps=$portagedeps
	    install="/usr/bin/emerge"
 			if $download http://$SERIAL:$KEY@software.virtualmin.com/$os_type/$arch/virtualmin-release-latest.tar.gz
				return $?
  		then continue
  		else
  		fatal "Failed to download virtualmin-release package for $os_type.  Cannot continue."
			fi
 		;;
		debian)
			package_type="deb"
			deps=$debdeps
	    install="/usr/bin/apt-get -y install"
	    # XXX Make sure universe is available, and all CD repos are disabled
      if $download http://$SERIAL:$KEY@software.virtualmin.com/$os_type/$os_version/$arch/virtualmin-release-latest_$arch.deb
      then 
				res=`dpkg -i virtualmin-release-latest_$arch.deb`
				logger_debug "dpkg returned: $?"
			else
				fatal "Failed to download virtualmin-release package for $os_type.  Cannot continue."
			fi
		;;
		*)
	    logger_info "Your OS is not currently supported by this installer.  Please contact us at"
	    logger_info "support@virtualmin.com to let us know what OS you'd like to install Virtualmin"
	    logger_info "Professional on, and we'll try to help."
      exit 1
		;;
	esac
}

# Functions
install_with_yum () {
	threelines
	logger_info "Installing Virtualmin and all related packages now using the command:"
	logger_info "yum -y $virtualminmeta"

	if yum -y install $virtualminmeta; then
		logger_info "Installation of $virtualminmeta completed."
	else
		fatal "Installation failed: $?"
	fi

  logger_info "If you are not regularly updating your system nightly using yum or up2date"
  logger_info "we strongly recommend you update now, using the following commands:"
  logger_info "Fedora/CentOS: yum update"
  logger_info "RHEL: up2date -u; yum update"
	return 0
}

install_with_yast () {
	threelines
	logger_info "Installing Virtualmin and all related packages now using the command:"
	logger_info "$install $virtualminmeta"
	sources=`y2pmsh source -s | grep "^[[:digit:]]" | cut -d ":" -f 1`
	if [ "$sources" != "" ]; then
		logger_info "Disabling existing y2pmsh sources."
		y2pmsh source -d $sources
	fi

	if $install $virtualminmeta; then
		logger_info "Installation completed."
		logger_debug "$install returned: $?"
	else
		fatal "Installation failed: $?"
	fi
	if [ "$sources" != "" ]; then
		logger_info "Re-enabling any pre-existing sources."
		y2pmsh source -e $sources
	fi

  logger_info "If you are not regularly updating your system nightly using yum or up2date"
  logger_info "we strongly recommend you update now, using yast."
	return 0
}

install_with_urpmi () {
	threelines
	logger_info "Installing Virtualmin and all related packages now using the command:"
	logger_info "urpmi $virtualminmeta"

	if urpmi $virtualminmeta; then
		logger_info "Installation of $virtualminmeta completed."
	else
		fatal "Installation failed: $?"
	fi

  logger_info "If you are not regularly updating your system nightly using yum or up2date"
  logger_info "we strongly recommend you update now, using the following commands:"
  logger_info "urpmi.update -a"
  logger_info "urpmi --auto-select"
	return 0
}

install_deps_the_hard_way () {
	logger_info "Installing dependencies using command: $install $deps"
	if $install $deps
	then return 0
	else
		logger_info "Something went wrong during installation: $?"
	fi
	exit $?
}

install_virtualmin () {
	case $package_type in
		rpm)
			case $os_type in
				suse)
					install_with_yast
					;;
				mandr*)
					install_with_urpmi
					;;
				*)
					install_with_yum
					;;
			esac
			;;
		deb)
			install_with_apt
			;;
    ebuild)
      install_with_emerge
      ;;
		*)
			install_with_tar
			;;
	esac
	return 0
}

# We may have to use $install to pre-install all deps.
install_virtualmin_release
if [ "$mode" = "full" ]; then
	install_deps_the_hard_way
fi

install_virtualmin

# Functions that are used in the OS specific modifications section
disable_selinux () {
	seconfigfiles="/etc/selinux/config /etc/sysconfig/selinux"
  for i in $seconfigfiles; do
		if [ -e $i ]; then
			sed -i "s/SELINUX=.*/SELINUX=disabled/" $i
		fi
	done
}

# Changes that are specific to OS
case $os_type in
  "fedora" | "centos" | "rhel"  )
		disable_selinux
		;;
esac

exit 0
