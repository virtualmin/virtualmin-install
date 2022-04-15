#!/bin/sh
# shellcheck disable=SC2059 disable=SC2181 disable=SC2154
# virtualmin-install.sh
# Copyright 2005-2021 Virtualmin, Inc.
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
# See here: https://www.virtualmin.com/documentation/installation/manual/

# License and version
SERIAL=GPL
KEY=GPL
VER=7.0.0-RC1
vm_version=7
upgrade_virtualmin_host=software.virtualmin.com

# Currently supported systems:
supported="    Red Hat Enterprise Linux derivatives
      - Alma Linux and Rocky 8 on x86_64
      - CentOS 7 and CentOS Stream 8 and 9 on x86_64
      - RHEL Linux 7 and 8 on x86_64

    Debian Linux derivatives
      - Ubuntu 20.04 LTS and 22.04 LTS (beta) on i386 and amd64
      - Debian 10 and 11 on i386 and amd64"

log=/root/virtualmin-install.log
skipyesno=0

# Print usage info, if --help, set mode, etc.
# Temporary colors
RED="$(tput setaf 1)"
YELLOW="$(tput setaf 3)"
CYAN="$(tput setaf 6)"
BLACK="$(tput setaf 16)"
NORMAL="$(tput sgr0)"
GREEN=$(tput setaf 2)

# Set defaults
bundle='LAMP' # Other option is LEMP
mode='full'   # Other option is minimal

usage() {
  # shellcheck disable=SC2046
  printf "Usage: %s %s [options]\\n" "${CYAN}" $(basename "$0")
  echo
  echo "  If called without arguments, installs Virtualmin."
  echo
  printf "  ${YELLOW}--uninstall|-u${NORMAL} - Removes all Virtualmin packages (do not use on a production system)\\n"
  printf "  ${YELLOW}--help|-h${NORMAL} - This message\\n"
  printf "  ${YELLOW}--force|-f${NORMAL} - Skip confirmation message\\n"
  printf "  ${YELLOW}--hostname|-n${NORMAL} - Set fully qualified hostname\\n"
  printf "  ${YELLOW}--verbose|-v${NORMAL} - Verbose\\n"
  printf "  ${YELLOW}--setup|-s${NORMAL} - Setup software repositories and exit (no installation or configuration)\\n"
  printf "  ${YELLOW}--minimal|-m${NORMAL} - Install a smaller subset of packages for low-memory/low-resource systems\\n"
  printf "  ${YELLOW}--bundle|-b <name>${NORMAL} - Choose bundle to install (LAMP or LEMP, defaults to LAMP)\\n"
  printf "  ${YELLOW}--disable <feature>${NORMAL} - Disable feature [SCL]\\n"
  echo
}

while [ "$1" != "" ]; do
  case $1 in
  --help | -h)
    usage
    exit 0
    ;;
  --uninstall | -u)
    shift
    mode="uninstall"
    ;;
  --force | -f | --yes | -y)
    shift
    skipyesno=1
    ;;
  --hostname | -n)
    shift
    forcehostname=$1
    shift
    ;;
  --verbose | -v)
    shift
    VERBOSE=1
    ;;
  --setup | -s)
    shift
    setup_only=1
    mode='setup'
    break
    ;;
  --minimal | -m)
    shift
    mode='minimal'
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
    *)
      printf "Unknown feature ${YELLOW}$1${NORMAL}: exiting\\n"
      exit 1
      ;;
    esac
    ;;
  --bundle | -b)
    shift
    case "$1" in
    LAMP)
      shift
      bundle='LAMP'
      ;;
    LEMP)
      shift
      bundle='LEMP'
      ;;
    *)
      printf "Unknown bundle ${YELLOW}$1${NORMAL}: exiting\\n"
      exit 1
      ;;
    esac
    ;;
  *)
    printf "Unrecognized option: $1\\n\\n"
    usage
    exit 1
    ;;
  esac
done

# Check if current time is not older than September 30, 2021,
# which is the expiration date of IdentTrust DST Root CA X3
TIME=`date +%s`
if [ "$TIME" -lt 1632960000 ]; then
  TIMESTR=`date`
  echo "$0: current system time ${YELLOW}$TIMESTR${NORMAL} is incorrect! It must be fixed manually to continue."
  exit
fi

echo "Running ${GREEN}Virtualmin ${vm_version}${NORMAL} pre-installation setup:"
echo "  Applying system packages upgrades .."

# Update all system packages first
printf "Running system packages upgrades ..\\n" >>$log
if [ -x /usr/bin/dnf ]; then
  dnf -y update >>$log
elif [ -x /usr/bin/yum ]; then
  yum -y update >>$log
elif [ -x /usr/bin/apt-get ]; then
  apt-get -y upgrade >>$log
fi
echo "  .. done"

# Make sure Perl is installed
printf "Checking for Perl ..\\n" >>$log
# loop until we've got a Perl or until we can't try any more
while true; do
  perl="$(which perl 2>/dev/null)"
  if [ -z "$perl" ]; then
    if [ -x /usr/bin/perl ]; then
      perl=/usr/bin/perl
      break
    elif [ -x /usr/local/bin/perl ]; then
      perl=/usr/local/bin/perl
      break
    elif [ -x /opt/csw/bin/perl ]; then
      perl=/opt/csw/bin/perl
      break
    elif [ "$perl_attempted" = 1 ]; then
      printf ".. ${RED}Perl could not be installed. Cannot continue.${NORMAL}\\n"
      exit 2
    fi
    # couldn't find Perl, so we need to try to install it
    echo "  Attempting to install Perl .."
    if [ -x /usr/bin/dnf ]; then
      dnf -y install perl >>$log
    elif [ -x /usr/bin/yum ]; then
      yum -y install perl >>$log
    elif [ -x /usr/bin/apt-get ]; then
      apt-get update >>$log
      apt-get -q -y install perl >>$log
    fi
    perl_attempted=1
    # Loop. Next loop should either break or exit.
  else
    break
  fi
done
if [ "$perl_attempted" = 1 ]; then
  echo "  .. done"
fi
printf ".. found Perl at $perl\\n" >>$log

# Check for wget or curl or fetch
printf "Checking for HTTP client .." >>$log
while true; do
  if [ -x "/usr/bin/wget" ]; then
    download="/usr/bin/wget -nv"
    break
  elif [ -x "/usr/bin/curl" ]; then
    download="/usr/bin/curl -f -s -L -O"
    break
  elif [ -x "/usr/bin/fetch" ]; then
    download="/usr/bin/fetch"
    break
  elif [ "$wget_attempted" = 1 ]; then
    printf ".. ${RED}no HTTP client available. Could not install wget. Cannot continue.${NORMAL}\\n"
    exit 1
  fi

  # Made it here without finding a downloader, so try to install one
  wget_attempted=1
  if [ -x /usr/bin/dnf ]; then
    dnf -y install wget >>$log
  elif [ -x /usr/bin/yum ]; then
    yum -y install wget >>$log
  elif [ -x /usr/bin/apt-get ]; then
    apt-get update >>/dev/null
    apt-get -y -q install wget >>$log
  fi
done
if [ -z "$download" ]; then
  echo "Tried to install downloader, but failed. Do you have working network and DNS?"
fi
printf " found %s\\n" "$download" >>$log

# Check for gpg, debian 10 doesn't install by default!?
if [ -x /usr/bin/apt-get ]; then
  if [ ! -x /usr/bin/gpg ]; then
    printf "GPG not found, attempting to install .." >>$log
    apt-get update >>/dev/null
    apt-get -y -q install gnupg >>$log
  fi
fi

arch="$(uname -m)"
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
vmgrouptext="Virtualmin provided"
debvmpackages="virtualmin-core"
deps=
sclgroup="'Software Collections PHP 7.2 Environment'"

# This has to be installed before anything else, so it can be disabled during
# install, and turned back on after. This is ridiculous.
debpredeps="fail2ban"

if [ "$mode" = 'full' ]; then
  if [ "$bundle" = 'LAMP' ]; then
    rhgroup="'Virtualmin LAMP Stack'"
    rhgrouptext="Virtualmin LAMP stack"
    debdeps="postfix virtualmin-lamp-stack"
    ubudeps="postfix virtualmin-lamp-stack"
  elif [ "$bundle" = 'LEMP' ]; then
    rhgroup="'Virtualmin LEMP Stack'"
    rhgrouptext="Virtualmin LEMP stack"
    debdeps="postfix php*-fpm virtualmin-lemp-stack"
    ubudeps="postfix php*-fpm virtualmin-lemp-stack"
  fi
elif [ "$mode" = 'minimal' ]; then
  if [ "$bundle" = 'LAMP' ]; then
    rhgroup="'Virtualmin LAMP Stack Minimal'"
    rhgrouptext="Virtualmin LAMP stack minimal"
    debdeps="postfix virtualmin-lamp-stack-minimal"
    ubudeps="postfix virtualmin-lamp-stack-minimal"
  elif [ "$bundle" = 'LEMP' ]; then
    rhgroup="'Virtualmin LEMP Stack Minimal'"
    rhgrouptext="Virtualmin LEMP stack minimal'"
    debdeps="postfix php*-fpm virtualmin-lemp-stack-minimal"
    ubudeps="postfix php*-fpm virtualmin-lemp-stack-minimal"
  fi
fi

# Find temp directory
if [ -z "$TMPDIR" ]; then
  TMPDIR=/tmp
fi

# Check whether $TMPDIR is mounted noexec (everything will fail, if so)
# XXX: This check is imperfect. If $TMPDIR is a full path, but the parent dir
# is mounted noexec, this won't catch it.
TMPNOEXEC="$(grep $TMPDIR /etc/mtab | grep noexec)"
if [ -n "$TMPNOEXEC" ]; then
  echo "${RED}Fatal:${NORMAL} $TMPDIR directory is mounted noexec. Cannot continue."
  exit 1
fi

if [ -z "$tempdir" ]; then
  tempdir="$TMPDIR/.virtualmin-$$"
  if [ -e "$tempdir" ]; then
    rm -rf "$tempdir"
  fi
  mkdir "$tempdir"
fi

# "files" subdir for libs
mkdir "$tempdir/files"
srcdir="$tempdir/files"
if ! cd "$srcdir"; then
  echo "Failed to cd to $srcdir"
  exit 1
fi

# Download the slib (source: http://github.com/virtualmin/slib)
# Lots of little utility functions.
$download "https://$upgrade_virtualmin_host/lib/slib.sh" >>$log 2>&1
if [ $? -ne 0 ]; then
  echo "${RED}Error:${NORMAL} Failed to download utility function library. Cannot continue. Check your network connection and DNS settings."
  exit 1
fi
chmod +x slib.sh
# shellcheck disable=SC1091
. ./slib.sh

# Check the serial number and key
serial_ok "$SERIAL" "$KEY"
# Setup slog
# shellcheck disable=SC2034
LOG_PATH="$log"
# Setup run_ok
# shellcheck disable=SC2034
RUN_LOG="$log"
# Exit on any failure during shell stage
# shellcheck disable=SC2034
RUN_ERRORS_FATAL=1

# Console output level; ignore debug level messages.
if [ "$VERBOSE" = "1" ]; then
  # shellcheck disable=SC2034
  LOG_LEVEL_STDOUT="DEBUG"
else
  # shellcheck disable=SC2034
  LOG_LEVEL_STDOUT="INFO"
fi
# Log file output level; catch literally everything.
# shellcheck disable=SC2034
LOG_LEVEL_LOG="DEBUG"

# log_fatal calls log_error
log_fatal() {
  log_error "$1"
}

remove_virtualmin_release() {
  # shellcheck disable=SC2154
  case "$os_type" in
  "fedora" | "centos" | "rhel" | "amazon" | "rocky" | "almalinux" | "ol")
    run_ok "rpm -e virtualmin-release" "Removing virtualmin-release"
    ;;
  "debian" | "ubuntu")
    grep -v "virtualmin" /etc/apt/sources.list >"$tempdir"/sources.list
    mv "$tempdir"/sources.list /etc/apt/sources.list
    rm -f /etc/apt/sources.list.d/virtualmin.list
    rm -f /etc/apt/auth.conf.d/virtualmin.conf
    rm -f /usr/share/keyrings/debian-virtualmin-*
    rm -f /usr/share/keyrings/debian-webmin.gpg
    ;;
  esac
}

fatal() {
  echo
  log_fatal "Fatal Error Occurred: $1"
  printf "${RED}Cannot continue installation.${NORMAL}\\n"
  remove_virtualmin_release
  if [ -x "$tempdir" ]; then
    log_warning "Removing temporary directory and files."
    rm -rf "$tempdir"
  fi
  log_fatal "If you are unsure of what went wrong, you may wish to review the log"
  log_fatal "in $log"
  exit 1
}

success() {
  log_success "$1 Succeeded."
}

# Function to find out if Virtualmin is already installed, so we can get
# rid of some of the warning message. Nobody reads it, and frequently
# folks run the install script on a production system; either to attempt
# to upgrade, or to "fix" something. That's never the right thing.
is_installed() {
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
uninstall() {
  # Very destructive, ask first.
  echo
  printf "  ${REDBG}WARNING${NORMAL}\\n"
  echo
  echo "  This operation is very destructive. It removes nearly all of the packages"
  echo "  installed by the Virtualmin installer. Never run this on a production system."
  echo
  printf " Continue? (y/n) "
  if ! yesno; then
    exit
  fi

  # This is a crummy way to detect package manager...but going through
  # half the installer just to get here is even crummier.
  if which rpm 1>/dev/null 2>&1; then
    package_type=rpm
  elif which dpkg 1>/dev/null 2>&1; then
    package_type=deb
  fi

  case "$package_type" in
  rpm)
    yum groupremove -y --setopt="groupremove_leaf_only=true" "Virtualmin Core"
    yum groupremove -y --setopt="groupremove_leaf_only=true" "Virtualmin LAMP Stack"
    yum groupremove -y --setopt="groupremove_leaf_only=true" "Virtualmin LEMP Stack"
    yum groupremove -y --setopt="groupremove_leaf_only=true" "Virtualmin LAMP Stack Minimal"
    yum groupremove -y --setopt="groupremove_leaf_only=true" "Virtualmin LEMP Stack Minimal"
    yum remove -y virtualmin-base
    yum remove -y wbm-virtual-server wbm-virtualmin-htpasswd wbm-virtualmin-dav wbm-virtualmin-mailman wbm-virtualmin-awstats wbm-php-pear wbm-ruby-gems wbm-virtualmin-registrar wbm-virtualmin-init wbm-jailkit wbm-virtualmin-git wbm-virtualmin-slavedns wbm-virtual-server wbm-virtualmin-sqlite wbm-virtualmin-svn
    yum remove -y wbt-virtual-server-mobile
    yum remove -y virtualmin-config perl-Term-Spinner-Color
    yum remove -y webmin usermin awstats
    yum remove -y nginx
    yum remove -y fail2ban
    yum clean all
    os_type="centos"
    ;;
  deb)
    rm -rf /etc/fail2ban/jail.d/00-firewalld.conf
    rm -f /etc/fail2ban/jail.local
    apt-get remove --assume-yes --purge virtualmin-base virtualmin-core virtualmin-lamp-stack virtualmin-lemp-stack
    apt-get remove --assume-yes --purge virtualmin-lamp-stack-minimal virtualmin-lemp-stack-minimal
    apt-get remove --assume-yes --purge virtualmin-config libterm-spinner-color-perl
    apt-get remove --assume-yes --purge webmin-virtual-server webmin-virtualmin-htpasswd webmin-virtualmin-git webmin-virtualmin-slavedns webmin-virtualmin-dav webmin-virtualmin-mailman webmin-virtualmin-awstats webmin-php-pear webmin-ruby-gems webmin-virtualmin-registrar webmin-virtualmin-init webmin-jailkit webmin-virtual-server webmin-virtualmin-sqlite webmin-virtualmin-svn
    apt-get remove --assume-yes --purge webmin-virtual-server-mobile
    apt-get remove --assume-yes --purge fail2ban
    apt-get remove --assume-yes --purge apache2*
    apt-get remove --assume-yes --purge nginx*
    apt-get remove --assume-yes --purge webmin usermin
    apt-get autoremove --assume-yes
    os_type="debian"
    apt-get clean
    ;;
  *)
    echo "I don't know how to uninstall on this operating system."
    ;;
  esac
  echo 'Removing nameserver 127.0.0.1 from /etc/resolv.conf'
  sed -i '/nameserver 127.0.0.1/g' /etc/resolv.conf
  echo 'Removing virtualmin repo configuration'
  remove_virtualmin_release
  echo "Removing /etc/virtualmin-license, if it exists."
  rm /etc/virtualmin-license
  echo "Done.  There's probably quite a bit of related packages and such left behind"
  echo "but all of the Virtualmin-specific packages have been removed."
  exit 0
}
if [ "$mode" = "uninstall" ]; then
  uninstall
fi

# Calculate disk space requirements (this is a guess, for now)
if [ "$mode" = 'minimal' ]; then
  disk_space_required=500
else
  disk_space_required=650
fi

# Message to display in interactive mode
install_msg() {
  cat <<EOF

  Welcome to the Virtualmin ${GREEN}$PRODUCT${NORMAL} installer, version ${GREEN}$VER${NORMAL}

  This script must be run on a freshly installed supported OS. It does not
  perform updates or upgrades (use your system package manager) or license
  changes (use the "virtualmin change-license" command).

  The systems currently supported by install script are:

EOF
  echo "${CYAN}$supported${NORMAL}"
  cat <<EOF

  If your OS/version/arch is not listed, installation ${RED}will fail${NORMAL}. More
  details about the systems supported by the script can be found here:

    ${UNDERLINE}https://www.virtualmin.com/os-support${NORMAL}

  The selected package bundle is ${CYAN}${bundle}${NORMAL} and the size of install is
  ${CYAN}${mode}${NORMAL}. It will require up to ${CYAN}${disk_space_required} MB${NORMAL} of disk space.

  Exit and re-run this script with ${CYAN}--help${NORMAL} flag to see available options.

EOF

  printf " Continue? (y/n) "
  if ! yesno; then
    exit
  fi
}
if [ "$skipyesno" -ne 1 ] && [ -z "$setup_only" ]; then
  install_msg
fi

already_installed_msg() {
  # Double check if installed, just in case above error ignored.
  if is_installed; then
    cat <<EOF

  ${REDBG} WARNING! ${NORMAL}

  Virtualmin may already be installed. This can happen if an installation failed,
  and can be ignored in that case.

  However, if Virtualmin has already been successfully installed you ${BOLD}${RED}must not${NORMAL}
  run this script again! It will cause breakage to your existing configuration.

  Virtualmin repositories can be fixed using ${WHITEBG}${BLACK}${BOLD}${0##*/} -s${NORMAL} command.

  License details can be changed using ${WHITEBG}${BLACK}${BOLD}virtualmin change-license${NORMAL} command.
  Changing the license never requires re-installation.

  Updates and upgrades must be performed from within either Virtualmin or using
  system package manager on the command line.

EOF
    printf " Really Continue? (y/n) "
    if ! yesno; then
      exit
    fi
  fi
}
if [ "$skipyesno" -ne 1 ] && [ -z "$setup_only" ]; then
  already_installed_msg
fi

# Check memory
if [ "$mode" = "full" ]; then
  minimum_memory=1610613
else
  # minimal mode probably needs less memory to succeed
  minimum_memory=1048576
fi
if ! memory_ok "$minimum_memory"; then
  log_fatal "Too little memory, and unable to create a swap file. Consider adding swap"
  log_fatal "or more RAM to your system."
  exit 1
fi

# Check for localhost in /etc/hosts
if [ -z "$setup_only" ]; then
  grep localhost /etc/hosts >/dev/null
  if [ "$?" != 0 ]; then
    log_warning "There is no localhost entry in /etc/hosts. This is required, so one will be added."
    run_ok "echo 127.0.0.1 localhost >> /etc/hosts" "Editing /etc/hosts"
    if [ "$?" -ne 0 ]; then
      log_error "Failed to configure a localhost entry in /etc/hosts."
      log_error "This may cause problems, but we'll try to continue."
    fi
  fi
fi

# download()
# Use $download to download the provided filename or exit with an error.
download() {
  # XXX Check this to make sure run_ok is doing the right thing.
  # Especially make sure failure gets logged right.
  # awk magic prints the filename, rather than whole URL
  download_file=$(echo "$1" | awk -F/ '{print $NF}')
  run_ok "$download $1" "Downloading Virtualmin release package"
  if [ $? -ne 0 ]; then
    fatal "Failed to download Virtualmin release package. Cannot continue. Check your network connection and DNS settings."
  else
    return 0
  fi
}

# Only root can run this
id | grep -i "uid=0(" >/dev/null
if [ "$?" != "0" ]; then
  uname -a | grep -i CYGWIN >/dev/null
  if [ "$?" != "0" ]; then
    fatal "${RED}Fatal:${NORMAL} The Virtualmin install script must be run as root"
  fi
fi

log_info "Started installation log in $log"
if [ -n "$setup_only" ]; then
  log_debug "Phase 1 of 1: Setup"
  printf "${YELLOW}▣${NORMAL} Phase ${YELLOW}1${NORMAL} of ${GREEN}1${NORMAL}: Setup\\n"
else
  log_debug "Phase 1 of 3: Setup"
  printf "${YELLOW}▣${CYAN}□□${NORMAL} Phase ${YELLOW}1${NORMAL} of ${GREEN}3${NORMAL}: Setup\\n"
fi

# Print out some details that we gather before logging existed
log_debug "Install mode: $mode"
log_debug "Product: Virtualmin $PRODUCT"
log_debug "install.sh version: $VER"

# Check for a fully qualified hostname
log_debug "Checking for fully qualified hostname .."
name="$(hostname -f)"
if [ -n "$forcehostname" ]; then
  set_hostname "$forcehostname"
elif ! is_fully_qualified "$name"; then
  set_hostname
fi

# Insert the serial number and password into /etc/virtualmin-license
log_debug "Installing serial number and license key into /etc/virtualmin-license"
echo "SerialNumber=$SERIAL" >/etc/virtualmin-license
echo "LicenseKey=$KEY" >>/etc/virtualmin-license
chmod 700 /etc/virtualmin-license
cd ..

# Populate some distro version globals
get_distro
log_debug "Operating system name:    $os_real"
log_debug "Operating system version: $os_version"
log_debug "Operating system type:    $os_type"
log_debug "Operating system major:   $os_major_version"

install_virtualmin_release() {
  # Grab virtualmin-release from the server
  log_debug "Configuring package manager for ${os_real} ${os_version} .."
  case "$os_type" in
  rhel | centos | rocky | almalinux | ol | fedora | amazon)
    case "$os_type" in
    rhel | centos)
      if [ "$os_major_version" -lt 7 ]; then
        printf "${RED}${os_type} ${os_version} is not supported by this installer.${NORMAL}\\n"
        exit 1
      fi
      ;;
    rocky | almalinux | ol)
      if [ "$os_major_version" -lt 8 ]; then
        printf "${RED}${os_type} ${os_version} is not supported by this installer.${NORMAL}\\n"
        exit 1
      fi
      ;;
    fedora)
      if [ "$os_version" -lt 33 ]; then
        printf "${RED}${os_type} ${os_version} is not supported by this installer.${NORMAL}\\n"
        exit 1
      fi
      ;;
    *)
      printf "${RED}This OS/version is not recognized. Cannot continue.${NORMAL}\\n"
      exit 1
      ;;
    esac
    if [ -x /usr/sbin/setenforce ]; then
      log_debug "Disabling SELinux during installation .."
      if /usr/sbin/setenforce 0 1>/dev/null 2>&1; then
        log_debug " setenforce 0 succeeded"
      else
        log_debug "  setenforce 0 failed: $?"
      fi
    fi
    package_type="rpm"
    if which dnf 1>/dev/null 2>&1; then
      install="dnf -y install"
      install_cmd="dnf"
      install_group="dnf -y --quiet group install --setopt=group_package_types=mandatory,default"
      install_config_manager="dnf config-manager"
      if ! $install_config_manager 1>/dev/null 2>&1; then
        run_ok "$install dnf-plugins-core" "Installing core plugins for package manager"
      fi
    else
      install="/usr/bin/yum -y install"
      install_cmd="/usr/bin/yum"
      if [ "$os_major_version" -ge 7 ]; then
        run_ok "yum --quiet groups mark convert" "Updating yum Groups"
      fi
      install_group="yum -y --quiet groupinstall --setopt=group_package_types=mandatory,default"
      install_config_manager="yum-config-manager"
    fi
    os_type_repo="$os_type"
    if [ "$os_type" = "ol" ]; then
      os_type_repo='rhel'
    fi
    download "https://${LOGIN}$upgrade_virtualmin_host/vm/${vm_version}/${repopath}${os_type_repo}/${os_major_version}/${arch}/virtualmin-release-latest.noarch.rpm"
    run_ok "rpm -U --replacepkgs --quiet virtualmin-release-latest.noarch.rpm" "Installing Virtualmin release package"
    # XXX This weirdly only seems necessary on CentOS 8, but harmless
    # elsewhere.
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-webmin
    ;;
  debian | ubuntu)
    case "$os_type" in
    ubuntu)
      if [ "$os_version" != "18.04" ] && [ "$os_version" != "20.04" ] && [ "$os_version" != "22.04" ]; then
        printf "${RED}${os_type} ${os_version} is not supported by this installer.${NORMAL}\\n"
        exit 1
      fi
      ;;
    debian)
      if [ "$os_major_version" -lt 10 ]; then
        printf "${RED}${os_type} ${os_version} is not supported by this installer.${NORMAL}\\n"
        exit 1
      fi
      ;;
    esac
    package_type="deb"
    if [ "$os_type" = "ubuntu" ]; then
      deps="$ubudeps"
      case "$os_version" in
      18.04*)
        repos="virtualmin-bionic virtualmin-universal"
        ;;
      20.04*)
        repos="virtualmin-focal virtualmin-universal"
        ;;
      22.04*)
        repos="virtualmin-jammy virtualmin-universal"
        ;;
      esac
    else
      deps="$debdeps"
      case "$os_version" in
      9*)
        repos="virtualmin-stretch virtualmin-universal"
        ;;
      10*)
        repos="virtualmin-buster virtualmin-universal"
        ;;
      11*)
        repos="virtualmin-bullseye virtualmin-universal"
        ;;
      esac
    fi
    log_debug "apt-get repos: ${repos}"
    if [ -z "$repos" ]; then # Probably unstable with no version number
      log_fatal "No repos available for this OS. Are you running unstable/testing?"
      exit 1
    fi
    # Remove any existing repo config, in case it's a reinstall
    remove_virtualmin_release
    apt_auth_dir='/etc/apt/auth.conf.d'
    for repo in $repos; do
      printf "deb [signed-by=/usr/share/keyrings/debian-virtualmin-$vm_version.gpg] https://${LOGIN}$upgrade_virtualmin_host/vm/${vm_version}/${repopath}apt ${repo} main\\n" >>/etc/apt/sources.list.d/virtualmin.list
    done
    if [ -n "$LOGIN" ]; then
      printf "machine $upgrade_virtualmin_host login $SERIAL password $KEY\\n" >>"$apt_auth_dir/virtualmin.conf"
    fi

    # Install our keys
    log_debug "Installing Webmin and Virtualmin package signing keys .."
    download "https://$upgrade_virtualmin_host/lib/RPM-GPG-KEY-virtualmin-$vm_version"
    download "https://$upgrade_virtualmin_host/lib/RPM-GPG-KEY-webmin"
    run_ok "gpg --import RPM-GPG-KEY-virtualmin-$vm_version && cat RPM-GPG-KEY-virtualmin-$vm_version | gpg --dearmor > /usr/share/keyrings/debian-virtualmin-$vm_version.gpg" "Installing Virtualmin $vm_version key"
    run_ok "gpg --import RPM-GPG-KEY-webmin && cat RPM-GPG-KEY-webmin | gpg --dearmor > /usr/share/keyrings/debian-webmin.gpg" "Installing Webmin key"

    run_ok "apt-get update" "Downloading repository metadata"
    # Make sure universe repos are available
    # XXX Test to make sure this run_ok syntax works as expected (with single quotes inside double)
    if [ $os_type = "ubuntu" ]; then
      if [ -x "/bin/add-apt-repository" ] || [ -x "/usr/bin/add-apt-repository" ]; then
        run_ok "add-apt-repository universe" \
          "Enabling universe repositories, if not already available"
      else
        run_ok "sed -ie '/backports/b; s/#*[ ]*deb \\(.*\\) universe$/deb \\1 universe/' /etc/apt/sources.list" \
          "Enabling universe repositories, if not already available"
      fi
    fi
    # XXX Is this still enabled by default on Debian/Ubuntu systems?
    run_ok "sed -ie 's/^deb cdrom:/#deb cdrom:/' /etc/apt/sources.list" "Disabling cdrom: repositories"
    install="DEBIAN_FRONTEND='noninteractive' /usr/bin/apt-get --quiet --assume-yes --install-recommends -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' -o Dpkg::Pre-Install-Pkgs::='/usr/sbin/dpkg-preconfigure --apt' install"
    #export DEBIAN_FRONTEND=noninteractive
    install_updates="$install $deps"
    run_ok "apt-get clean" "Cleaning up software repo metadata"
    sed -i "s/\\(deb[[:space:]]file.*\\)/#\\1/" /etc/apt/sources.list
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

# Setup repos only
if [ -n "$setup_only" ]; then
  if install_virtualmin_release; then
    log_success "Repository configuration successful. You can now install Virtualmin"
    log_success "components using your OS package manager."
  else
    log_error "Errors occurred during setup of Virtualmin software repositories. You may find more"
    log_error "information in ${RUN_LOG}."
  fi
  exit $?
fi

# Install Functions
install_with_apt() {
  # Install Webmin first, because it needs to be already done for the deps
  run_ok "$install webmin" "Installing Webmin"
  run_ok "$install usermin" "Installing Usermin"
  for d in $debpredeps; do
    run_ok "$install $d" "Installing $d"
  done
  if [ $bundle = 'LEMP' ]; then
    # This is bloody awful. I can't believe how fragile dpkg is here.
    for s in fail2ban ipchains apache2; do
      systemctl stop "$s" >>${RUN_LOG} 2>&1
      systemctl disable "$s" >>${RUN_LOG} 2>&1
    done
    apt-get remove --assume-yes --purge apache2* php* >>${RUN_LOG} 2>&1
    apt-get autoremove --assume-yes >>${RUN_LOG} 2>&1
    run_ok "$install nginx-common" "Installing nginx-common"
    sed -i 's/listen \[::\]:80 default_server;/#listen \[::\]:80 default_server;/' /etc/nginx/sites-available/default
  else
    # This is bloody awful. I can't believe how fragile dpkg is here.
    for s in fail2ban nginx; do
      systemctl stop "$s" >>${RUN_LOG} 2>&1
      systemctl disable "$s" >>${RUN_LOG} 2>&1
    done
    apt-get remove --assume-yes --purge nginx* php* >>${RUN_LOG} 2>&1
    apt-get autoremove --assume-yes >>${RUN_LOG} 2>&1
  fi
  for d in ${deps}; do
    run_ok "$install ${d}" "Installing $d"
  done
  run_ok "$install ${debvmpackages}" "Installing Virtualmin and all related packages"
  if [ $? -ne 0 ]; then
    log_warning "apt-get seems to have failed. Are you sure your OS and version is supported?"
    log_warning "https://www.virtualmin.com/os-support"
    fatal "Installation failed: $?"
  fi

  # Make sure the time is set properly
  /usr/sbin/ntpdate-debian >>${RUN_LOG} 2>&1

  return 0
}

install_with_yum() {
  # RHEL 8 specific setup
  if [ "$os_major_version" -ge 8 ] && [ "$os_type" = "rhel" ]; then
    # Important Perl packages are now hidden in CodeReady repo
    run_ok "$install_config_manager --set-enabled codeready-builder-for-rhel-$os_major_version-x86_64-rpms" "Enabling Red Hat CodeReady package repository"
    download "https://dl.fedoraproject.org/pub/epel/epel-release-latest-$os_major_version.noarch.rpm"
    run_ok "rpm -U --replacepkgs --quiet epel-release-latest-$os_major_version.noarch.rpm" "Installing EPEL $os_major_version release package"
  # RHEL 7 specific setup
  elif [ "$os_major_version" -eq 7 ] && [ "$os_type" = "rhel" ]; then
    download "https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"
    run_ok "rpm -U --replacepkgs --quiet epel-release-latest-7.noarch.rpm" "Installing EPEL 7 release package"
  # install extras from EPEL and SCL
  elif [ "$os_type" = "centos" ] || [ "$os_type" = "rocky" ] || [ "$os_type" = "almalinux" ]; then
    install_epel_release "epel-release"
    if [ "$os_major_version" -lt 8 ]; then
      # No SCL on CentOS 8
      install_scl_php
    fi
  elif [ "$os_type" = "ol" ]; then
    install_epel_release "oracle-epel-release-el$os_major_version"
  fi

  # Important Perl packages are now hidden in PowerTools repo
  if [ "$os_major_version" -ge 8 ] && [ "$os_type" = "centos" ] || [ "$os_type" = "rocky" ] || [ "$os_type" = "almalinux" ]; then
    # Detect PowerTools repo name
    powertools=$(dnf repolist all | grep "^powertools")
    powertoolsname="PowerTools"
    if [ ! -z "$powertools" ]; then
      powertools="powertools"
    else
      powertools="PowerTools"
    fi

    # CentOS 9 Stream changed the name to CBR
    if [ "$os_major_version" -ge 9 ] && [ "$os_type" = "centos" ]; then
      powertools=$(dnf repolist all | grep "^crb")
      if [ ! -z "$powertools" ]; then
        powertools="crb"
        powertoolsname="CRB"
      fi
    fi
    run_ok "$install_config_manager --set-enabled $powertools" "Enabling $powertoolsname package repository"
  fi


  # Important Perl packages are hidden in ol8_codeready_builder repo in Oracle
  if [ "$os_major_version" -ge 8 ] && [ "$os_type" = "ol" ]; then
    run_ok "$install_config_manager --set-enabled ol${os_major_version}_codeready_builder" "Oracle Linux $os_major_version CodeReady Builder"
  fi

  # XXX This is so stupid. Why does yum insists on extra commands?
  if [ "$os_major_version" -eq 7 ]; then
    run_ok "yum --quiet groups mark install $rhgroup" "Marking $rhgrouptext for install"
    run_ok "yum --quiet groups mark install $vmgroup" "Marking $vmgrouptext for install"
  fi
  
  # Clear cache and install system packages upgrades first
  run_ok "$install_cmd clean all" "Cleaning up software repo metadata"

  run_ok "$install_group $rhgroup" "Installing dependencies and system packages"
  run_ok "$install_group $vmgroup" "Installing Virtualmin and all related packages"
  if [ $? -ne 0 ]; then
    fatal "Installation failed: $?"
  fi


  return 0
}

install_virtualmin() {
  case "$package_type" in
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

install_epel_release() {
  if [ -z "$DISABLE_EPEL" ]; then
    run_ok "$install $1" "Installing EPEL release package"
  fi
}

install_scl_php() {
  if [ -z "$DISABLE_SCL" ]; then
    run_ok "$install yum-utils" "Installing core plugins for package manager"
    run_ok "$install_config_manager --enable extras >/dev/null" "Enabling Extras package repository"
    run_ok "$install scl-utils" "Installing utilities for alternative packaging"
    if [ "${os_type}" = "centos" ]; then
      run_ok "$install centos-release-scl" "Installing SCL release package"
    elif [ "${os_type}" = "rhel" ]; then
      run_ok "$install_config_manager --enable rhel-server-rhscl-${os_major_version}-rpms" "Enabling SCL package repository"
    fi
    run_ok "$install_group $sclgroup" "Installing PHP 7"
  fi
}

# virtualmin-release only exists for one platform...but it's as good a function
# name as any, I guess.  Should just be "setup_repositories" or something.
errors=$((0))
install_virtualmin_release
echo
log_debug "Phase 2 of 3: Installation"
printf "${GREEN}▣${YELLOW}▣${CYAN}□${NORMAL} Phase ${YELLOW}2${NORMAL} of ${GREEN}3${NORMAL}: Installation\\n"
install_virtualmin
if [ "$?" != "0" ]; then
  errorlist="${errorlist}  ${YELLOW}◉${NORMAL} Package installation returned an error.\\n"
  errors=$((errors + 1))
fi

# We want to make sure we're running our version of packages if we have
# our own version.  There's no good way to do this, but we'll
run_ok "$install_updates" "Installing updates to Virtualmin related packages"
if [ "$?" != "0" ]; then
  errorlist="${errorlist}  ${YELLOW}◉${NORMAL} Installing updates returned an error.\\n"
  errors=$((errors + 1))
fi

# Reap any clingy processes (like spinner forks)
# get the parent pids (as those are the problem)
allpids="$(ps -o pid= --ppid $$) $allpids"
for pid in $allpids; do
  kill "$pid" 1>/dev/null 2>&1
done

# Final step is configuration. Wait here for a moment, hopefully letting any
# apt processes disappear before we start, as they're huge and memory is a
# problem. XXX This is hacky. I'm not sure what's really causing random fails.
sleep 1
echo
log_debug "Phase 3 of 3: Configuration"
printf "${GREEN}▣▣${YELLOW}▣${NORMAL} Phase ${YELLOW}3${NORMAL} of ${GREEN}3${NORMAL}: Configuration\\n"
if [ "$mode" = "minimal" ]; then
  bundle="Mini${bundle}"
fi
virtualmin-config-system --bundle "$bundle"
if [ "$?" != "0" ]; then
  errorlist="${errorlist}  ${YELLOW}◉${NORMAL} Postinstall configuration returned an error.\\n"
  errors=$((errors + 1))
fi
config_system_pid=$!

# Functions that are used in the OS specific modifications section
disable_selinux() {
  seconfigfiles="/etc/selinux/config /etc/sysconfig/selinux"
  for i in $seconfigfiles; do
    if [ -e "$i" ]; then
      perl -pi -e 's/^SELINUX=.*/SELINUX=disabled/' "$i"
    fi
  done
}

# Changes that are specific to OS
case "$os_type" in
"fedora" | "centos" | "rhel" | "amazon" | "rocky" | "almalinux" | "ol")
  disable_selinux
  ;;
esac

# kill the virtualmin config-system command, if it's still running
kill "$config_system_pid" 1>/dev/null 2>&1
# Make sure the cursor is back (if spinners misbehaved)
tput cnorm

printf "${GREEN}▣▣▣${NORMAL} Cleaning up\\n"
# Cleanup the tmp files
if [ "$tempdir" != "" ] && [ "$tempdir" != "/" ]; then
  log_debug "Cleaning up temporary files in $tempdir."
  find "$tempdir" -delete
else
  log_error "Could not safely clean up temporary files because TMPDIR set to $tempdir."
fi

if [ -n "$QUOTA_FAILED" ]; then
  log_warning "Quotas were not configurable. A reboot may be required. Or, if this is"
  log_warning "a VM, configuration may be required at the host level."
fi
echo
if [ $errors -eq "0" ]; then
  hostname=$(hostname -f)
  detect_ip
  log_success "Installation Complete!"
  log_success "If there were no errors above, Virtualmin should be ready"
  log_success "to configure at https://${hostname}:10000 (or https://${address}:10000)."
  log_success "You may receive a security warning in your browser on your first visit."
else
  log_warning "The following errors occurred during installation:"
  echo
  printf "${errorlist}"
fi

exit 0
