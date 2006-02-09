#!/bin/sh
# virtualmin-install.sh
# Copyright 2005 Virtualmin, Inc.
# Simple script to grab the virtualmin-release and virtualmin-base packages.
# The packages do most of the hard work, so this script can be small-ish and 
# lazy-ish.

# WARNING: Anything not listed in the currently supported systems list is not
# going to work, despite the fact that you might see code that detects your
# OS and acts on it.  If it isn't in the list, the code is not complete and
# will not work.  Don't even bother trying it.  Trust me.

# Currently supported systems:
# Fedora Core 3 and 4 on i386 and x86_64
# CentOS and RHEL 3 and 4 on i486 and x86_64
# SuSE 9.3 and OpenSUSE 10.0 on i586

LANG=
export LANG

SERIAL=ZZZZZZZZ
KEY=sdfru8eu38jjdf
VER=EA2a
arch=`uname -i`
vmpackages="usermin webmin wbm-virtualmin-awstats wbm-virtualmin-dav wbm-virtualmin-dav wbm-virtualmin-htpasswd wbm-virtualmin-svn wbm-virtual-server wbt-virtualmin-nuvola* ust-virtualmin-nuvola*"
deps=
# Red Hat-based systems 
rhdeps="httpd-devel postfix bind spamassassin procmail perl perl-DBD-Pg perl-DBD-MySQL quota iptables openssl python mailman subversion ruby rdoc ri mysql mysql-server postgresql postgresql-server rh-postgresql rh-postgresql-server logrotate webalizer php php-domxl php-gd php-imap php-mysql php-odbc php-pear php-pgsql php-snmp php-xmlrpc mod_perl mod_python cyrus-sasl dovecot spamassassin mod_dav_svn"
# SUSE systems (SUSE and OpenSUSE)
yastdeps="webmin usermin postfix bind perl-spamassassin spamassassin procmail perl-DBI perl-DBD-Pg perl-DBD-mysql quota openssl mailman subversion ruby mysql mysql-Max mysql-administrator mysql-client mysql-shared postgresql postgresql-pl postgresql-libs postgresql-server webalizer apache2 apache2-devel apache2-mod_fastcgi apache2-mod_perl apache2-mod_python apache2-mod_php4 apache2-mod_ruby apache2-worker apache2-prefork clamav awstats dovecot cyrus-sasl proftpd php4 php4-domxml php4-gd php4-imap php4-mysql php4-mbstring php4-pgsql php4-pear php4-session"
# Mandrake/Mandriva
urpmideps="apache2 apache2-common apache2-manual apache2-metuxmpm apache2-mod_dav apache2-mod_fastcgi apache2-mod_ldap apache2-mod_perl apache2-mod_php apache2-mod_proxy apache2-mod_ssl apache2-modules apache2-peruser apache2-worker clamav clamav-db clamd bind bind-utils cyrus-sasl postfix postfix-ldap postgresql postgresql-contrib postgresql-docs postgresql-pl postgresql-plperl postgresql-server proftpd proftpd-anonymous quota perl-Net_SSLeay perl-DBI perl-DBD-Pg perl-DBD-mysql spamassassin perl-Mail-SpamAssassin mailman subversion subversion-server MySQL MySQL-common MySQL-client MySQL-Max openssl ruby"
# Debian-based systems (Ubuntu and Debian)
debdeps="postfix postfix-tls bind9 spamassassin spamc procmail perl libnet-ssleay-perl libpg-perl libdbd-pg-perl libdbd-mysql-perl quota iptables openssl python mailman subversion ruby irb rdoc ri mysql mysql-server mysql-client mysql-admin-common mysql-common postgresql postgresql-client logrotate awstats webalizer php4 clamav awstats dovecot cyrus-sasl proftpd proftpd-common proftpd-doc proftpd-ldap proftpd-mysql proftpd-pgsql"
# Ports-based systems (FreeBSD, NetBSD, OpenBSD)
portsdeps="postfix bind9 p5-Mail-SpamAssassin procmail perl p5-Class-DBI-Pg p5-Class-DBI-mysql setquota openssl python mailman subversion ruby irb rdoc ri mysql-client mysql-server postgresql-client postgresql-server postgresql-contrib logrotate awstats webalizer php4 clamav dovecot cyrus-sasl"
# Gentoo
portagedeps="postfix bind spamassassin procmail perl DBD-Pg DBD-mysql quota openssl python mailman subversion ruby irb rdoc mysql postgresql logrotate awstats webalizer php Net-SSLeay iptables clamav dovecot"

# == Some simple functions ==
threelines () {
	echo
	echo
	echo
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
	logger_fatal "Attempting to remove virtualmin-release, so the installation can be "
	logger_fatal "re-attempted after any problems have been resolved."
	remove_virtualmin_release
	logger_fatal "If you are unsure of what went wrong, you may wish to review the log"
	logger_fatal "in virtualmin-install.log."
	exit
}

remove_virtualmin_release () {
	case $os_type in
		"fedora" | "centos" |	"rhel"	)	rpm -e virtualmin-release;;
		"suse"	)
			vmsrcs=`y2pmsh source -s | grep "virtualmin" | grep "^[[:digit:]]" | cut -d ":" -f 1`
			y2pmsh source -R $vmsrcs
			;;
	esac
}

accept_if_fully_qualified () {
	case $1 in
	localhost.localdomain)
		echo "Hostname cannot be localhost.localdomain.  Installation cannot continue."
		exit 1
		;;
	*.*)
		echo "Hostname OK: fully qualified as $1"
		return 0
		;;
	esac
	echo "Hostname $name is not fully qualified.  Installation cannot continue."
	exit 1
}

success () {
	logger_info "Succeeded."
}

# == End of functions ==


cat <<EOF
***********************************************************************
*   Welcome to the Virtualmin Professional installer, version $VER    *
***********************************************************************

 WARNING: This is an Early Adopter release.  It may not be wholly 
 compatible with future releases of the installer.  We don't expect
 major problems, but be prepared for some occasional discomfort on
 upgrades for a few weeks.  Be sure to let us know when problems arise
 by creating issues in the bugtracker at Virtualmin.com.


 The installer in its current form cannot safely perform an upgrade 
 of an existing Virtualmin GPL system.  An upgradeable installer will
 be available in a couple of days.

EOF
printf " Continue? (y/n) "
if yesno
then continue
else exit
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
get_mode
# If minimal, we don't install any extra packages, or perform any configuration
if [ "$mode" = minimal ]; then
	rhdeps=yastdeps=debdeps=portagedeps=portsdeps=""
	virtualminmeta=$vmpackages
fi

# Check for a fully qualified hostname
echo "Checking for fully qualified hostname..."
name=`hostname -f`
accept_if_fully_qualified $name

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

# Insert the serial number and password into /etc/virtualmin-license
echo "SerialNumber=$SERIAL" > /etc/virtualmin-license
echo "LicenseKey=$KEY"	>> /etc/virtualmin-license

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
	echo "Could not load logging library from software.virtualmin.com.  Cannot continue."
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
      autoos=2
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
			logger_info "Disabling SELinux during installation..."
			res=`/usr/sbin/setenforce 0`
			logger_debug "setenforce 0 returned $res"
			package_type="rpm"
			deps=$rhdeps
			if [ -e /usr/bin/yum ]; then
				continue
			else
				# Install yum, which makes installing and upgrading our packages easier
 				if $download http://$SERIAL:$KEY@software.virtualmin.com/$os_type/$os_version/$arch/yum-latest.noarch.rpm
				then
					logger_info "yum not found, installing yum from software.virtualmin.com..."
					res=`rpm -Uvh yum-latest.noarch.rpm`
					logger_debug $res
  				continue
  			else
    			fatal "Failed to download yum package for $os_type.  Cannot continue."
				fi
			fi
			if $download http://$SERIAL:$KEY@software.virtualmin.com/$os_type/$os_version/$arch/virtualmin-release-latest.noarch.rpm
			then
				res=`rpm -Uvh virtualmin-release-latest.noarch.rpm`
				logger_debug $res
				success
			else
				fatal "Failed to download virtualmin-release package for $os_type.  Cannot continue."
			fi
		;;
		suse)
			# No release for suse.  Their RPM locks when we try to import keys...
			package_type="rpm"
			deps=$yastdeps
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
			package_type="tar"
  		deps=$portagedeps
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
			if $download http://$SERIAL:$KEY@software.virtualmin.com/$os_type/$os_version/$arch/virtualmin-release-latest_$arch.deb
			then 
				res=`dpkg -i virtualmin-release-latest_$arch.deb`
				logger_debug "dpkg returned: $?"
			else
				fatal "Failed to download virtualmin-release package for $os_type.  Cannot continue."
			fi
		;;
		*)
			fatal "Your OS/version does not seem to be supported at this time."
		;;
	esac
}

# Choose apt-get, y2pmsh, yum, or up2date to install the deps
if [ "$os_type" = "fedora" ]; then
	install="/usr/bin/yum -y install"
elif [ "$os_type" = "rhel" ]; then
	install="/usr/bin/up2date --nox"
	rpm --import /usr/share/rhn/RPM-GPG-KEY
elif [ "$os_type" = "suse" ]; then
	install="/sbin/yast -i"
elif [ "$os_type" = "mandriva" ]; then
	install="/usr/bin/urpmi"
elif [ "$os_type" = "debian" ]; then
	install="/usr/bin/apt-get -y install"
elif [ "$os_type" = "gentoo" ]; then
	install="/usr/bin/emerge"
else
	logger_info "Your OS is not currently supported by this installer.  Please contact us at"
	logger_info "support@virtualmin.com to let us know what OS you'd like to install Virtualmin"
	logger_info "Professional on, and we'll try to help."
	exit
fi

# Functions
install_with_yum () {
	threelines
	logger_info "Installing Virtualmin and all related packages now using the command:"
	logger_info "$install $virtualminmeta"

	if yum -y install $virtualminmeta; then
		logger_info "Installation of $virtualminmeta completed."
	else
		logger_info "Installation failed: $?"
		logger_info "Removing virtualmin-release package, so that installation can be re-attempted"
		logger_info "after any problems reported are resolved."
		return $?
	fi

	logger_info "Updating all packages to the latest versions now using the command:"
	logger_info "yum -y update"
	if yum -y update; then
		logger_info "Update completed successfully."
		logger_debug "yum returned: $?"
	else
		logger_info "Update failed: $?"
		logger_info "This probably isn't directly harmful, but correcting the problem is recommended."
		logger_info "It is likely that yum is misconfigured or network access is unavailable."
	fi
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

#	if y2pmsh install $virtualminmeta; then
	if $install $virtualminmeta; then
		logger_info "Installation completed."
		logger_debug "$install returned: $?"
		return 0
	else
		logger_info "Installation failed: $?"
		logger_info "Removing virtualmin-release package, so that installation can be re-attempted"
		logger_info "after any problems reported are resolved."
		return $?
	fi
	if [ "$sources" != "" ]; then
		logger_info "Re-enabling any existing sources."
		y2pmsh source -e $sources
	fi
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
# Install with yum or from tarball
# Install virtualmin-release so we know where to find our packages and 
# how to install them
	logger_info "Package Type = $package_type"
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
		*)
			install_with_tar
			;;
	esac
	return 0
}

# We may have to use $install to pre-install all deps.
install_virtualmin_release
install_deps_the_hard_way
case $os_type in
	fedora)
    install_with_yum # Everyting is simple with yum...
  	;;
	suse)
    install_with_yast
  	;;
	debian)
		install_with_apt
		;;
	mandrake)
		install_with_urpmi
		;;
	gentoo)
		install_with_emerge
		;;
	*)
    install_virtualmin
		;;
esac

# Functions that are used in the OS specific modifications section
disable_selinux () {
	seconfigfiles="/etc/selinux/config /etc/sysconfig/selinux"
  for i in $seconfigfiles; do
		if [ -e $i ]; then
			sed -i "s/SELINUX=.*/SELINUX=disabled/" $i
		fi
	done
}

fix_mailman_config () {
# Fix RHEL/CentOS Mailman config
if [ "$os_type" = "rhel" ]; then
  case $os_version in
  3*)
    cp /usr/libexec/webmin/virtualmin-mailman/config-redhat-linux /etc/webmin/virtualmin-mailman/config
    ;;
  4*)
    cp /usr/libexec/webmin/virtualmin-mailman/config-redhat-linux-11.0-\* /etc/webmin/virtualmin-mailman/config
		;;
	esac
fi
}

# Changes that are specific to OS
case $os_type in
  "fedora" | "centos" | "rhel"  )
		disable_selinux
		fix_mailman_config
		;;
esac

exit 0
