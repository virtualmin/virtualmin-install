# virtualmin-install
Shell script to perform a Virtualmin GPL or Professional installation

# How it Works
The script relies on our software repositories on software.virtualmin.com in order to function. You'll need internet access.

It sets up or downloads the software repository configuration file for your OS (yum/dnf on RHEL/CentOS/Scientific or 
apt-get on Debian/Ubuntu), and runs the necessary commands to download and install all of the stuff needed for a
Virtualmin web hosting system. This is includes OS-standard packages or MySQL or MariaDB, Postfix, Dovecot, procmail,
Mailman, PHP, Python, Ruby, SpamAssassin, ClamAV, BIND, and many others. When no OS-standard package is available or
the standard package needs tweaks, we provide it in our repository and fetch it from there.

# Supported Operating Systems
This is currently in flux as old systems are removed and new systems are added/tested.

Currently, well-supported systems are:

  - CentOS/RHEL/Scientific 5, 6, 7
  - Debian 6, 7, 8
  - Ubuntu 12.04 LTS, 14.04, and 16.04 LTS
  
Previously working, but probably moderately broken now (and missing repository support at software.virtualmin.com) includes SuSE and FreeBSD.

# How to run it
Download it to your server, and run it as root (yes, it has to run as root, this is systems management software).

    # wget -O install.sh http://software.virtualmin.com/gpl/scripts/install.sh
    # /bin/sh install.sh

Note that if you have Virtualmin Professional, the process is a little different (or you have to edit the script to add your serial number and key to the SERIAL and KEY variables). You can retrieve your license information from the 
"Software Licenses" on your account page at Virtualmin.com. If you don't have Pro but want to get it, visit:
https://www.virtualmin.com/buy/virtualmin

# How to contribute

Wrap your head around how install.sh does its job (requires a "virtualmin-base" package for your distro/version and 
a software repository, all of which will be documented in their respective git repos). Ask questions if you're not sure what's going on.

Pick your favorite distro or OS, and start coding and packaging for it! I'm usually happy to devote time and resources 
to helping make Virtualmin work on other systems. I just don't have the time/resources to maintain more than the 
most popular server operating systems myself.
