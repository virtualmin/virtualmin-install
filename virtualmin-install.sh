#!/bin/sh
# virtualmin-install.sh
# Copyright 2005 Virtualmin, Inc.
# Simple script to grab the virtualmin-release and virtualmin-base packages.
# The packages do most of the hard work, so this script can be small and 
# lazy.

# WARNING: Anything not listed in the currently supported systems list is not
# going to work, despite the fact that you might see code that detects your
# OS and acts on it.  If it isn't in the list, the code is not complete and
# will not work.  Don't even bother trying it.  Trust me.

# Currently supported systems:
# Fedora Core 3 and 4 for i386 and x86_64
# CentOS and RHEL 3 and 4	i386 and x86_64

LANG=
export LANG

SERIAL=ZZZZZZZZ
KEY=sdfru8eu38jjdf
VER=EA2b
arch=i386 # XXX need to detect x86_64
deps=
# RPM-based systems (maybe needs to be broken down by OS)
rhdeps="postfix bind spamassassin procmail perl perl-DBD-Pg perl-DBD-MySQL quota iptables openssl python mailman subversion ruby rdoc ri mysql mysql-server postgresql postgresql-server rh-postgresql rh-postgresql-server logrotate webalizer php mod_perl mod_python cyrus-sasl dovecot spamassassin"
yastdeps="webmin usermin postfix bind perl-spamassassin spamassassin procmail perl-DBI perl-DBD-Pg perl-DBD-mysql quota mailman subversion ruby mysql mysql-Max mysql-administrator mysql-client mysql-shared postgresql postgresql-pl postgresql-libs postgresql-server webalizer apache2 apache2-mod_fastcgi apache2-mod_perl apache2-mod_python apache2-mod_php4 apache2-mod_ruby apache2-worker apache2-prefork clamav awstats dovecot cyrus-sasl proftpd"
# Debian-based systems (Ubuntu and Debian)
debdeps="postfix postfix-tls bind9 spamassassin spamc procmail perl libnet-ssleay-perl libpg-perl libdbd-pg-perl libdbd-mysql-perl quota iptables openssl python mailman subversion ruby irb rdoc ri mysql mysql-server mysql-client mysql-admin-common mysql-common postgresql postgresql-client logrotate awstats webalizer php4 clamav awstats dovecot cyrus-sasl"
# Ports-based systems (FreeBSD, NetBSD, OpenBSD)
portsdeps="postfix bind9 p5-Mail-SpamAssassin procmail perl p5-Class-DBI-Pg p5-Class-DBI-mysql setquota openssl python mailman subversion ruby irb rdoc ri mysql-client mysql-server postgresql-client postgresql-server postgresql-contrib logrotate awstats webalizer php4 clamav dovecot cyrus-sasl"
# Gentoo
portagedeps="postfix bind spamassassin procmail perl DBD-Pg DBD-mysql quota openssl python mailman subversion ruby irb rdoc mysql postgresql logrotate awstats webalizer php Net-SSLeay iptables clamav dovecot"

threelines () {
	echo
	echo
	echo
}

fatal () {
	echo
	echo "Fatal Error Occurred: $1"
	echo "Cannot continue installation."
	echo "Attempting to remove virtualmin-release, so the installation can be "
	echo "re-attempted after any problems have been resolved."
	remove_virtualmin_release
	exit
}

remove_virtualmin_release () {
	case $os_type in
		"fedora" | "centos" |	"rhel"	)	rpm -e virtualmin-release;;
		"suse"	)
			vmsrcs=`y2pmsh source -s | grep "virtualmin" | grep "^[[:digit:]]" | cut -d ":" -f 1`
			y2pmsh source -R $vmsrcs
			sed -i "s/.*virtualmin.*//g" /etc/youservers
			;;
	esac
}

echo "***********************************************************************"
echo "*   Welcome to the Virtualmin Professional installer, version $VER    *"
echo "***********************************************************************"
echo ""
echo " WARNING: This is an Early Adopter release.  It may not be wholly "
echo " compatible with future releases of the installer.  We don't expect"
echo " major problems, but be prepared for some occasional discomfort on"
echo " upgrades for a few weeks.  Be sure to let us know when problems arise"
echo " by creating issues in the bugtracker at Virtualmin.com."
threelines
echo " Continue? (y/n)"
read line
case $line in
	y|Y)  continue;;
	*)		exit 0;;
esac
threelines
echo " INSTALL or UPGRADE "
echo " It is possible to upgrade an existing Virtualmin GPL installation,"
echo " or perform a minimal installation which only includes the Virtualmin"
echo " Professional Webmin modules and no additional packages.  The "
echo " minimal mode will not modify your existing configurations.  The "
echo " full install is recommended only if this system is a fresh install of"
echo " the OS.  Would you like to perform a minimal installation or"
echo " upgrade Virtualmin GPL?"
read line
case $line in
	y|Y)	mode=minimal
	;;
	*) 		mode=full;;
esac
threelines
echo "Installation type: $mode"
sleep 5
threelines

# Check for a fully qualified hostname
echo "Checking for fully qualified hostname..."
accept_if_fully_qualified() {
	case $1 in
	localhost.localdomain)
		echo "Hostname $name is not fully qualified.  Installation cannot continue."
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
name=`hostname`
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
if [ $? != "0" ]; then
	uname -a | grep -i CYGWIN >/dev/null
	if [ $? != "0" ]; then
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
	if [ -e "/tmp/.virtualmin" ]; then
		rm -rf /tmp/.virtualmin
	fi
	tempdir=/tmp/.virtualmin
	mkdir $tempdir
fi

# Detecting the OS
# Grab the Webmin oschooser.pl script
mkdir $tempdir/files
srcdir=$tempdir/files
cd $srcdir
if $download http://$SERIAL:$KEY@software.virtualmin.com/lib/oschooser.pl
then continue
else exit 1
fi
if $download http://$SERIAL:$KEY@software.virtualmin.com/lib/os_list.txt
then continue
else exit 1
fi
cd ..

# Get operating system type
echo "***********************************************************************"  
if [ "$os_type" = "" ]; then
  if [ "$autoos" = "" ]; then
      autoos=2
    fi
    $perl "$srcdir/oschooser.pl" "$srcdir/os_list.txt" $tempdir/$$.os $autoos
    if [ $? != 0 ]; then
      exit $?
    fi
    . $tempdir/$$.os
    rm -f $tempdir/$$.os
  fi
echo "Operating system name:    $real_os_type"
echo "Operating system version: $real_os_version"
threelines

install_virtualmin_release () {
	# Grab virtualmin-release from the server
	echo "Downloading virtualmin-release package for $real_os_type $real_os_version..."
	if [[ "$os_type" = "fedora" || $os_type = "rhel" || $os_type = "mandriva" || $os_type = "mandrake" ]]; then
		package_type="rpm"
		deps=$rhdeps
		if [ -e /usr/bin/yum ]; then
			continue
		else
			# Install yum, which makes installing and upgrading our packages easier
 			if $download http://$SERIAL:$KEY@software.virtualmin.com/$os_type/$os_version/$arch/yum-latest.noarch.rpm
			then
				echo "yum not found, installing yum from software.virtualmin.com..."
				rpm -Uvh yum-latest.noarch.rpm
  			continue
  		else
    		echo "Failed to download yum package for $os_type.  Cannot continue."
    		exit
			fi
		fi
		if $download http://$SERIAL:$KEY@software.virtualmin.com/$os_type/$os_version/$arch/virtualmin-release-latest.noarch.rpm
		then
			rpm -Uvh virtualmin-release-latest.noarch.rpm
		else
			echo "Failed to download virtualmin-release package for $os_type.  Cannot continue."
			exit
		fi
	elif [ "$os_type" = "suse" ]; then
		# No release for suse.  Their RPM locks when we try to import keys...
		package_type="rpm"
		deps=$yastdeps
		if yast -i y2pmsh; then
			continue
		else
			echo "Failed to install y2pmsh package.  Cannot continue."
			exit 0
		fi
		if y2pmsh source -a http://$SERIAL:$KEY@software.virtualmin.com/$os_type/$os_version; then
			continue
		else
			fatal "Unable to add yast2 installation source."
		fi
		if y2pmsh source -a http://$SERIAL:$KEY@software.virtualmin.com/universal; then
			continue
		else
			fatal "Unable to add yast2 installation source."
    fi
#		echo "Adding SuSE $os_version yast repository.  This will take a while."
#		if y2pmsh source -a http://mirrors.kernel.org/suse/i386/$os_version; then
#      continue
#    else
#      fatal "Unable to add yast2 installation source."
#    fi
#		echo "Adding Virtualmin repositories to /etc/youservers..."
#		echo "http://$SERIAL:$KEY@software.virtualmin.com/$os_type/$os_version" >> /etc/youservers
#		echo "http://$SERIAL:$KEY@software.virtualmin.com/universal" >> /etc/youservers
	elif [ "$os_type" = "freebsd" ]; then
		package_type="tar"
		deps=$portsdeps
		if $download http://$SERIAL:$KEY@software.virtualmin.com/$os_type/$arch/virtualmin-release-latest.tar.gz
		then continue
		else
			echo "Failed to download virtualmin-release package for $os_type.  Cannot continue."
			exit 0
			exit
		fi
	elif [ "$os_type" = "gentoo" ]; then
		package_type="tar"
  	deps=$portagedeps
 		if $download http://$SERIAL:$KEY@software.virtualmin.com/$os_type/$arch/virtualmin-release-latest.tar.gz
			return $?
  	then continue
  	else
  		echo "Failed to download virtualmin-release package for $os_type.  Cannot continue."
    	exit
		fi
	elif [ "$os_type" = "debian" ]; then
		package_type="deb"
		deps=$debdeps
		if $download http://$SERIAL:$KEY@software.virtualmin.com/$os_type/$os_version/$arch/virtualmin-release-latest_$arch.deb
		then 
			dpkg -i virtualmin-release-latest_$arch.deb	
		else
			echo "Failed to download virtualmin-release package for $os_type.  Cannot continue."
			exit
		fi
	fi
  return $?
}

# Choose apt-get, y2pmsh, yum, or up2date to install the deps
if [ "$os_type" = "fedora" ]; then
	install="/usr/bin/yum -y install"
elif [ "$os_type" = "rhel" ]; then
	install="/usr/bin/up2date --nox"
	rpm --import /usr/share/rhn/RPM-GPG-KEY
elif [ "$os_type" = "suse" ]; then
	install="/usr/bin/y2pmsh isc"
elif [ "$os_type" = "mandriva" ]; then
	install="/usr/bin/urpmi"
elif [ "$os_type" = "debian" ]; then
	install="/usr/bin/apt-get -y install"
elif [ "$os_type" = "gentoo" ]; then
	install="/usr/bin/emerge"
else
	echo "Your OS is not currently supported by this installer.  Please contact us at"
	echo "support@virtualmin.com to let us know what OS you'd like to install Virtualmin"
	echo "Professional on, and we'll try to help."
	exit 1
fi

# Functions
install_with_yum () {
	threelines
	echo "Installing Virtualmin and all related packages now using the command:"
	echo "yum -y install virtualmin-base"

	if yum -y install virtualmin-base; then
		echo "Installation completed."
		return 0
	else
		echo "Installation failed: $?"
		echo "Removing virtualmin-release package, so that installation can be re-attempted"
		echo "after any problems reported are resolved."
		return $?
	fi
}

install_with_yast () {
	threelines
	echo "Installing Virtualmin and all related packages now using the command:"
	echo "y2pmsh install virtualmin-base"
	sources=`y2pmsh source -s | grep "^[[:digit:]]" | cut -d ":" -f 1`
	if [ $sources != "" ]; then
		echo "Disabling existing y2pmsh sources."
		y2pmsh source -d $sources
	fi

	if y2pmsh install virtualmin-base; then
		echo "Installation completed."
		return 0
	else
		echo "Installation failed: $?"
		echo "Removing virtualmin-release package, so that installation can be re-attempted"
		echo "after any problems reported are resolved."
		return $?
	fi
	if [ $sources != "" ]; then
		echo "Re-enabling any existing sources."
		y2pmsh source -e $sources
	fi
}

install_deps_the_hard_way () {
	echo "Installing dependencies using command: $install $deps"
	if $install $deps
	then return 0
	else
		echo "Something went wrong during installation: $?"
	fi
	exit $?
}

install_virtualmin () {
# Install with yum or from tarball
# Install virtualmin-release so we know where to find our packages and 
# how to install them
	echo "package_type = $package_type"
	if [ "$package_type" = "rpm" ]; then
		if [ "$os_type" = "suse" ]; then
			install_with_yast
		elif [[ "$os_type" = "mandriva" || "$os_type" = "mandrake" ]]; then
			install_with_urpmi
		else
			install_with_yum
		fi
	elif [ "$package_type" = "deb" ]; then
		install_with_apt
	elif [ "$package_type" = "tar" ]; then
		install_with_tar
	fi
	return 0
}

# We may have to use $install to pre-install all deps.
if [ "$os_type" = "fedora" ]; then
  install_virtualmin_release # We need some data from this later
  install_deps_the_hard_way # Argh...virtualmin-base is broken...
	install_with_yum # Everyting is simple with yum...
elif [ "$os_type" = "suse" ]; then
	install_virtualmin_release
  install_deps_the_hard_way # Why doesn't yast resolve deps?!?!
	install_with_yast
else
  # If not yum, we have our work cut out for us...
	install_virtualmin_release # Must be run first to setup deps.
	install_deps_the_hard_way # Everything is pear-shaped without yum...
	install_virtualmin # Install the virtualmin packages and configure them.
fi

# Temporary fixes
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

exit 0
