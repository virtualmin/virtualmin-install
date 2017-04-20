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

# Some environment variables that control the installation:
# DISABLE_EPEL - Install will not enable EPEL repository on CentOS/RHEL.
#                Some features will not be available, in this case. Set it
#                1 to instruct the script not to enable EPEL.
# DISABLE_SCL  - Install will not enable the Software Collections Library
#                on CentOS/RHEL. PHP7 will not be installed. Set it to 1
#                to instruct the script not to enable SCL.
# DISABLE_PG   - Do not install Postgres.
# ENABLE_NGINX - Install will setup nginx, instead of Apache. This is
#                experimental. And, nginx is still much less capable than
#                Apache. Apache will NOT be installed/configured.

# Currently supported systems:
supported="    CentOS/RHEL Linux 6 and 7 on x86_64
    Debian 7 and 8 on i386 and amd64
    Ubuntu 14.04 LTS and 16.04 LTS, on i386 and amd64"

log=/root/virtualmin-install.log
skipyesno=0

# Print usage info, if --help, set mode, etc.
# Temporary colors
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
NORMAL=$(tput sgr0)
while [ "$1" != "" ]; do
	case $1 in
		--help|-h)
			printf "Usage: ${CYAN}$(basename $0) ${YELLOW}[--uninstall|-u|--help|-h|--force|-f|--hostname]${NORMAL}\n"
	  		echo
			echo "  If called without arguments, installs Virtualmin Professional."
			echo
			printf "  ${YELLOW}--uninstall|-u${NORMAL} - Removes all Virtualmin packages (do not use on a production system)\n"
			printf "  ${YELLOW}--help|-h${NORMAL} - This message\n"
			printf "  ${YELLOW}--force|-f:${NORMAL} - Skip confirmation message\n"
			printf "  ${YELLOW}--hostname|-host${NORMAL} - Set fully qualified hostname\n"
			printf "  ${YELLOW}--varbose|-v${NORMAL} - Verbose\n"
			printf "  ${YELLOW}--disable <feature>${NORMAL} - Disable feature [SCL|EPEL|PG]\n"
			echo
			exit 0
			;;
		--uninstall|-u)
			mode="uninstall"
			;;
		--force|-f|--yes|-y)
			shift
			skipyesno=1
			;;
		--hostname|--host)
			shift
			forcehostname=$1
      shift
			;;
		--verbose|-v)
			shift
			VERBOSE=1
			;;
		--disable)
			shift
			case "$1" in
				SCL)
					shift
					DISABLE_SCL=1
					;;
				EPEL)
					shift
					DISABLE_EPEL=1
					;;
				PG)
					shift
					DISABLE_PG=1
					;;
				*)
					printf "Unknown feature ${YELLOW}$1${NORMAL}: exiting\n"
					exit 1
					;;
			esac
			;;
		*)
			;;
	esac
	shift
done

# Make sure Perl is installed
printf "Checking for Perl..." >> $log
# loop until we've got a Perl or until we can't try any more
while true; do
	perl=$(which perl 2>/dev/null)
	if [ -z $perl ]; then
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
			printf "${RED}Perl could not be installed - Installation cannot continue.${NORMAL}\n"
			exit 2
		fi
		# couldn't find Perl, so we need to try to install it
       		echo 'Perl was not found on your system - Virtualmin requires it to run.'
		echo 'Attempting to install it now.'
		if [ -x /usr/bin/dnf ]; then
			dnf -y install perl >> $log
		elif [ -x /usr/bin/yum ]; then
			yum -y install perl >> $log
		elif [ -x /usr/bin/apt-get ]; then
			apt-get updatei >> $log
			apt-get -q -y install perl >> $log
		fi
		perl_attempted = 1
		# Loop. Next loop should either break or exit.
	else
		break
	fi
done
printf "found Perl at $perl\n" >> $log

# Check for wget or curl or fetch
printf "Checking for HTTP client..." >> $log
while true; do
	if [ -x "/usr/bin/curl" ]; then
		download="/usr/bin/curl -s -O"
		break
	elif [ -x "/usr/bin/wget" ]; then
		download="/usr/bin/wget -nv"
		break
	elif [ -x "/usr/bin/fetch" ]; then
		download="/usr/bin/fetch"
		break
	elif [ $curl_attempted = 1 ]; then
		printf "${RED}No HTPP client available. Could not install curl. Cannot continue.${NORMAL}"
		exit 1
	fi

	# Made it here without finding a downloader, so try to install one
	curl_attempted = 1
	if [ -x /usr/bin/dnf ]; then
		dnf -y install curl >> $log
	elif [ -x /usr/bin/yum ]; then
		yum -y install curl >> $log
	elif [ -x /usr/bin/apt-get ]; then
		apt-get update >> /dev/null
		apt-get -y -q install curl >> $log
	fi
done
printf "found %s\n" "$download" >> $log

SERIAL=GPL
KEY=GPL
VER=6.0.0
vm_version=6
echo "$SERIAL" | grep "[^a-z^A-Z^0-9]" && echo "Serial number $SERIAL contains invalid characters." && exit
echo "$KEY" | grep "[^a-z^A-Z^0-9]" && echo "License $KEY contains invalid characters." && exit

arch=$(uname -m)
if [ "$arch" = "i686" ]; then
	arch="i386"
fi
if [ "$SERIAL" = "GPL" ]; then
	LOGIN=""
	PRODUCT="GPL"
	repopath="gpl/"
else
	LOGIN="$SERIAL:$KEY@"
	PRODUCT="Professional"
	repopath=""
fi

# Virtualmin-provided packages
vmgroup="'Virtualmin Core'"
debvmpackages="usermin webmin webmin-virtualmin-awstats webmin-virtualmin-dav webmin-virtualmin-htpasswd webmin-virtualmin-git webmin-jailkit"
deps=
# Red Hat-based systems XXX Need switch for nginx
rhgroup="'Virtualmin LAMP Stack'"
rhnginxgroup="'Virtualmin LEMP Stack'"
# Debian
debdeps="bsdutils postfix postfix-pcre webmin usermin ruby libxml-simple-perl libcrypt-ssleay-perl unzip zip libfcgi-dev bind9 spamassassin spamc procmail procmail-wrapper libnet-ssleay-perl libpg-perl libdbd-pg-perl libdbd-mysql-perl quota iptables openssl python mailman subversion ruby irb rdoc ri mysql-server mysql-client mysql-common postgresql postgresql-client awstats webalizer dovecot-common dovecot-imapd dovecot-pop3d proftpd libcrypt-ssleay-perl awstats clamav-base clamav-daemon clamav clamav-freshclam clamav-docs clamav-testfiles libapache2-mod-fcgid apache2-suexec-custom scponly apache2 apache2-doc libsasl2-2 libsasl2-modules sasl2-bin php-pear php5 php5-cgi libapache2-mod-php5 php5-mysql jailkit"
# Ubuntu (uses odd virtual packaging for some packages that are separate on Debian!)
ubudeps="apt-utils bsdutils postfix postfix-pcre webmin usermin ruby libxml-simple-perl libcrypt-ssleay-perl unzip zip libfcgi-dev bind9 spamassassin spamc procmail procmail-wrapper libnet-ssleay-perl libpg-perl libdbd-pg-perl libdbd-mysql-perl quota iptables openssl python mailman subversion ruby irb rdoc ri mysql-server mysql-client mysql-common postgresql postgresql-client awstats webalizer dovecot-common dovecot-imapd dovecot-pop3d proftpd libcrypt-ssleay-perl awstats clamav-base clamav-daemon clamav clamav-freshclam clamav-docs clamav-testfiles libapache2-mod-fcgid apache2-suexec-custom scponly apache2 apache2-doc libsasl2-2 libsasl2-modules sasl2-bin php-pear php5 php5-cgi libapache2-mod-php5 php5-mysql jailkit"

# Find temp directory
if [ -z "$TMPDIR" ]; then
	TMPDIR=/tmp
fi

# Check whether $TMPDIR is mounted noexec (everything will fail, if so)
# XXX: This check is imperfect. If $TMPDIR is a full path, but the parent dir
# is mounted noexec, this won't catch it.
TMPNOEXEC=$(grep $TMPDIR /etc/mtab | grep noexec)
if [ ! -z "$TMPNOEXEC" ]; then
	echo "${RED}Fatal:${NORMAL} $TMPDIR directory is mounted noexec. Installation cannot continue."
	exit 1
fi

if [ -z "$tempdir" ]; then
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

# Download the slib (source: http://github.com/virtualmin/slib)
# Lots of little utility functions.
$download http://software.virtualmin.com/lib/slib.sh
chmod +x slib.sh
. ./slib.sh

# Setup slog
LOG_PATH=$log
# Setup run_ok
RUN_LOG=$log

# Console output level; ignore debug level messages.
if [ "$VERBOSE" = "1" ]; then
	LOG_LEVEL_STDOUT="DEBUG"
else
	LOG_LEVEL_STDOUT="INFO"
fi
# Log file output level; catch literally everything.
LOG_LEVEL_LOG="DEBUG"

# log_fatal calls log_error
log_fatal() {
	log_error $1
}

fatal () {
	echo
	log_fatal "Fatal Error Occurred: $1"
	printf "${RED}Cannot continue installation.${NORMAL}\n"
	remove_virtualmin_release
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
			run_ok "rpm -e virtualmin-release" "Removing virtualmin-release"
		;;
		"debian" | "ubuntu" )
			grep -v "virtualmin" /etc/apt/sources.list > "$tempdir"/sources.list
			mv "$tempdir"/sources.list /etc/apt/sources.list
		;;
	esac
}

success () {
	log_success "$1 Succeeded."
}

# Function to find out if Virtualmin is already installed, so we can get
# rid of some of the warning message. Nobody reads it, and frequently
# folks run the install script on a production system; either to attempt
# to upgrade, or to "fix" something. That's never the right thing.
is_installed () {
	if [ -f /etc/virtualmin-license ]; then
		# looks like it's been installed before
		return 0
	fi
	# XXX Probably not installed? Maybe we should remove license on uninstall, too.
	return 1
}

# This function performs a rough uninstallation of Virtualmin
# It is neither complete, nor correct, but it almost certainly won't break
# anything.  It is primarily useful for cleaning up a botched install, so you
# can run the installer again.
uninstall () {
	# This is a crummy way to detect package manager...but going through
	# half the installer just to get here is even crummier.
	if type -t rpm>/dev/null; then package_type=rpm
	elif type -t dpkg>/dev/null; then package_type=deb
	fi

	case $package_type in
		rpm)
			yum remove -y virtualmin-base
			yum remove -y wbm-virtual-server wbm-virtualmin-htpasswd wbm-virtualmin-dav wbm-virtualmin-mailman wbm-virtualmin-awstats wbm-php-pear wbm-ruby-gems wbm-virtualmin-registrar wbm-virtualmin-init wbm-jailkit
			yum remove -y wbt-virtual-server-mobile
			yum remove -y webmin usermin awstats
		;;
		deb)
			dpkg --purge virtualmin-base
			dpkg --purge webmin-virtual-server webmin-virtualmin-htpasswd webmin-virtualmin-dav webmin-virtualmin-mailman webmin-virtualmin-awstats webmin-php-pear webmin-ruby-gems webmin-virtualmin-registrar webmin-virtualmin-init webmin-jailkit
			dpkg --purge webmin-virtual-server-mobile
			dpkg --purge webmin usermin
			apt-get clean
		;;
		*)
			echo "I don't know how to uninstall on this operating system."
		;;
	esac
	remove_virtualmin_release
  echo "Removing /etc/virtualmin-license, if it exists."
	rm /etc/virtualmin-license
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

 The installation is quite stable and functional when run on a freshly
 installed supported Operating System. We strongly recommend you use
 the latest supported version of your preferred distribution.

 Please read the Virtualmin Installation Guide before proceeding if
 your system is not a freshly installed and supported OS.

 This script is not intended to update your system! It should only be
 used to perform your initial Virtualmin installation. Updates and
 upgrades can be performed from within Virtualmin or via the system
 package manager. License changes can be performed with the
 "virtualmin change-license" command.

 The systems currently supported by install.sh are:

EOF
echo "${CYAN}$supported${NORMAL}"
cat <<EOF

 If your OS/version is not listed above, this script will fail. More
 details about the systems supported by the script can be found here:

          ${UNDERLINE}http://www.virtualmin.com/os-support${NORMAL}

EOF
printf " Continue? (y/n) "
if ! yesno; then
	exit
fi

# Double check if installed, just in case above error ignored.
if is_installed; then
cat <<EOF

                      ${REDBG}WARNING${NORMAL}

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

# XXX Should be a minimal option
mode=full

# Check for localhost in /etc/hosts
grep localhost /etc/hosts >/dev/null
if [ "$?" != 0 ]; then
	log_warning "There is no localhost entry in /etc/hosts. This is required, so one will be added."
	run_ok "echo 127.0.0.1 localhost >> /etc/hosts" "Editing /etc/hosts"
	if [ $? -ne 0 ]; then
		log_error "Failed to configure a localhost entry in /etc/hosts."
		log_error "This may cause problems, but we'll try to continue."
	fi
fi

# download()
# Use $download to download the provided filename or exit with an error.
download() {
	# XXX Check this to make sure run_ok is doing the right thing.
	# Especially make sure failure gets logged right.
	# awk magic prints the filename, rather than whole URL
	run_ok "$download $1" "Downloading $(echo $1 |awk -F/ '{print $NF}')"
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

log_info "Started installation log in $log"

# Print out some details that we gather before logging existed
log_debug "Install mode: $mode"
log_debug "Product: Virtualmin $PRODUCT"
log_debug "Virtualmin Meta-Package list: $virtualminmeta"
log_debug "install.sh version: $VER"

# Check for a fully qualified hostname
log_debug "Checking for fully qualified hostname..."
name=$(hostname -f)
if ! is_fully_qualified "$name"; then set_hostname
elif [ "$forcehostname" != "" ]; then set_hostname
fi

# Insert the serial number and password into /etc/virtualmin-license
log_debug "Installing serial number and license key into /etc/virtualmin-license"
echo "SerialNumber=$SERIAL" > /etc/virtualmin-license
echo "LicenseKey=$KEY"	>> /etc/virtualmin-license
chmod 700 /etc/virtualmin-license

# Detecting the OS
# Grab the Webmin oschooser.pl script
run_ok "$download http://software.virtualmin.com/lib/oschooser.pl" "Loading OS selection library"
run_ok "$download http://software.virtualmin.com/lib/os_list.txt" "Loading OS list"

cd ..

# Populate some distro version globals
get_distro
log_debug "Operating system name:    $os_real"
log_debug "Operating system version: $os_version"
log_debug "Operating system type:    $os_type"
log_debug "Operating system major:   $os_major_version"

install_virtualmin_release () {
	# Grab virtualmin-release from the server
	log_debug "Configuring package manager for ${os_real} ${os_version}..."
	case $os_type in
		rhel|centos|fedora|amazon)
      case $os_type in
        rhel|centos)
          if [ $os_major_version -lt 6 ]; then
            printf "${RED}${os_type} ${os_version} is not supported by this installer.${NORMAL}\n"
            exit 1
          fi
          ;;
        fedora)
          if [ $os_version -ne 25 ]; then
            printf "${RED}${os_type} ${os_version} is not supported by this installer.${NORMAL}\n"
            exit 1
          fi
          ;;
        ubuntu)
          if [ $os_version != "14.04" ] && [ $os_version != "16.04" ]; then
            printf "${RED}${os_type} ${os_version} is not supported by this installer.${NORMAL}\n"
            exit 1
          fi
          ;;
        debian)
          if [ $os_major_version -lt 7 ]; then
            printf "${RED}${os_type} ${os_version} is not supported by this installer.${NORMAL}\n"
            exit 1
          fi
          ;;
        *)
          printf "${RED}This OS/version is not recognized. Can't continue.${NORMAL}\n"
          exit 1
          ;;
      esac
			if [ -x /usr/sbin/setenforce ]; then
				log_debug "Disabling SELinux during installation..."
				if /usr/sbin/setenforce 0; then log_debug " setenforce 0 succeeded"
				else log_warning "  setenforce 0 failed: $?"
				fi
			fi
			package_type="rpm"
			if type -t dnf; then
				install="dnf -y install"
				install_cmd="dnf"
				if [ $mode="full" ]; then
					install_group="dnf -y group install"
				else
					install_group="dnf -y group install --setopt=group_package_types=mandatory"
				fi
			else
				install="/usr/bin/yum -y install"
				install_cmd="/usr/bin/yum"
        run_ok "yum --quiet groups mark convert" "Updating yum Groups"
				if [ $mode="full" ]; then
					install_group="yum -y groupinstall"
				else
					install_group="yum -y groupinstall --setopt=group_package_types=mandatory"
				fi
			fi
			download "http://${LOGIN}software.virtualmin.com/vm/${vm_version}/${repopath}${os_type}/${os_major_version}/${arch}/virtualmin-release-latest.noarch.rpm"
			run_ok "rpm -U --replacepkgs --quiet virtualmin-release-latest.noarch.rpm" "Installing virtualmin-release package"
		;;
		debian | ubuntu)
			package_type="deb"
			if [ "$os_type" = "ubuntu" ]; then
				deps=$ubudeps
				case $os_version in
					14.04*)
						repos="virtualmin-trusty virtualmin-universal"
					;;
					16.04*)
						repos="virtualmin-xenial virtualmin-univseral"
					;;
				esac
			else
				deps=$debdeps
				case $os_version in
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
			log_debug "Installing Webmin and Virtualmin package signing keys..."
			download "http://software.virtualmin.com/lib/RPM-GPG-KEY-virtualmin"
			download "http://software.virtualmin.com/lib/RPM-GPG-KEY-webmin"
			log_debug $(apt-key add RPM-GPG-KEY-virtualmin)
			log_debug $(apt-key add RPM-GPG-KEY-webmin)
			log_debug $(apt-get update)
			log_debug "Removing Debian standard Webmin package, if they exist..."
			log_debug "Removing Debian apache packages..."
			log_debug $(apt-get -y --purge remove webmin-core apache apache2)
		;;
		*)
			log_error " Your OS is not currently supported by this installer."
			log_error " You can probably run Virtualmin Professional on your system, anyway,"
			log_error " but you'll have to install it using the manual installation process."
			exit 1
		;;
	esac

	return 0
}

# Install Functions
install_with_apt () {
	run_ok "$install $virtualminmeta" "Installing Virtualmin and all related packages"
	if [ $? -ne 0 ]; then
		log_warning "apt-get seems to have failed. Are you sure your OS and version is supported?"
		log_warning "http://www.virtualmin.com/os-support"
		fatal "Installation failed: $?"
	fi

		# XXX Maybe we can use --trivial-only to avoid starting services?
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


	run_ok "$install webmin-virtual-server webmin-virtualmin-awstats webmin-virtualmin-htpasswd" "Installing Virtualmin modules:"
        if [ $? -ne 0 ]; then
                log_warning "apt-get seems to have failed. Are you sure your OS and version is supported?"
                log_warning "http://www.virtualmin.com/os-support"
                fatal "Installation failed: $?"
        fi

        # Make sure the time is set properly
        /usr/sbin/ntpdate-debian

	return 0
}

install_with_yum () {
	# install extras from EPEL and SCL
	if [ "$os_type" = "centos" -o "$os_type" = "rhel" ]; then
		install_epel_release
		install_scl_php
	fi

	run_ok "$install_group $rhgroup" "Installing dependencies and system packages"
	run_ok "$install_group $vmgroup" "Installing Virtualmin and all related packages"
	if [ $? -ne 0 ]; then
		fatal "Installation failed: $?"
	fi

	run_ok "$install_cmd clean all" "Cleaning up software repo metadata"

	return 0
}

install_deps_the_hard_way () {
	# XXX Don't need for rpm distros, need to get metapackages for deb
	# to remove it completely/
	return 0
	run_ok "$install $deps" "Installing dependencies"
	if [ $? -ne 0 ]; then
		fatal "Something went wrong during installation: $?"
	fi
	return 0
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
	if [ $? -eq 0 ]; then
		return 0
	else
		return $?
	fi
}

install_epel_release () {
	if [ -z $DISABLE_EPEL ]; then
		download "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${os_major_version}.noarch.rpm"
		run_ok "rpm -U --replacepkgs --quiet epel-release-latest-${os_major_version}.noarch.rpm" "Installing EPEL release package"
		rpm --quiet --import '/etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7'
	fi
}

install_scl_php () {
	if [ -z $DISABLE_SCL ]; then
    run_ok "$install yum-utils" "Installing yum-utils"
		run_ok "yum-config-manager --enable extras >/dev/null" "Enabling extras repository"
    run_ok "$install scl-utils" "Installing scl-utils"
		if [ ${os_type} = "centos" ]; then
			run_ok "$install centos-release-scl" "Install Software Collections release package"
		elif [ ${os_type} = "rhel" ]; then
			# XXX Fix this for dnf (dnf config-manager, instead of yum-config-manager)
			run_ok "yum-config-manager --enable rhel-server-rhscl-${os_major_version}-rpms" "Enabling Server Software Collection"
		fi
		run_ok "$install rh-php70" "Installing PHP7"
		scl enable rh-php70 bash
	fi
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

log_success "Installation Complete!"
log_success "Assuming there were no errors above, your Virtualmin system should be ready"
log_success "to configure on port 10000."

exit 0
