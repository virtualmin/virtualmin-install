[![Build Status](https://travis-ci.com/virtualmin/virtualmin-install.svg?branch=master)](https://travis-ci.org/virtualmin/virtualmin-install)

# virtualmin-install
Shell script to perform a Virtualmin GPL or Professional installation

If you just want to install Virtualmin, go here and follow the instructions: [Virtualmin.com](https://www.virtualmin.com/download).

This repo is for people who want to read the source, contribute, help make the installer support other distros or operating systems, or make a customized installer.

# How it Works
The script relies on our software repositories on software.virtualmin.com in order to function. You'll need internet access.

It sets up or downloads the software repository configuration file for your OS (yum/dnf on RHEL/CentOS/Scientific or 
apt-get on Debian/Ubuntu), and runs the necessary commands to download and install all of the stuff needed for a
Virtualmin web hosting system. This is includes OS-standard packages or MySQL or MariaDB, Postfix, Dovecot, procmail,
Mailman, PHP, Python, Ruby, SpamAssassin, ClamAV, BIND, and many others. When no OS-standard package is available or
the standard package needs tweaks, we provide it in our repository and fetch it from there.

# Supported Operating Systems
This is currently in flux as old systems are removed and new systems are added/tested.

Currently, well-supported systems in the stable installer are:

  - CentOS/RHEL/Scientific 7 and 8
  - Debian 10
  - Ubuntu 18.04 LTS and 20.04 LTS
  
We strongly recommend you use the latest version of your preferred supported distribution. The latest release gets the most active testing and bug fixing.

Previously working, but probably moderately broken now (and missing repository support at software.virtualmin.com) includes SuSE and FreeBSD.

# How to run it

**Never run the install script on anything other than a freshly installed OS. It is for installation, not upgrading. An automated upgrade path to VM6 from VM5 will be provided in a couple of days.**

## Stable Version

Download it to your server, and run it as root (yes, it has to run as root, this is systems management software).

    # wget -O install.sh http://software.virtualmin.com/gpl/scripts/install.sh
    # /bin/sh install.sh

Note that if you have Virtualmin Professional, the process is a little different (or you have to edit the script to add your serial number and key to the SERIAL and KEY variables). You can retrieve your license information from the 
"Software Licenses" on your account page at Virtualmin.com. If you don't have Pro but want to get it, visit:
https://www.virtualmin.com/buy/virtualmin

## Pre-release Virtualmin 6 Version

Download it to your server from git:

    # wget -O install.sh https://raw.githubusercontent.com/virtualmin/virtualmin-install/master/virtualmin-install.sh
    # /bin/sh install.sh
    
If you're using Virtualmin Professional, you'll need to update the KEY and SERIAL variables inside the script (lines 171 and 172). Get that info from your Software Licenses page under Account on Virtualmin.com.

Please file tickets, either here or at Virtualmin.com, about bugs you find. The repositories currently only support CentOS 7, Debian 8, and Ubuntu 16.04. Older versions will be supported in a few days as I have time to package thing and test them, but we always recommend the latest version of your preferred distro.

# How to contribute

Wrap your head around how install.sh does its job (mostly by setting up package repositories and installed metapackages or yum groups). Ask questions if you're not sure what's going on.

Pick your favorite distro or OS, and start coding and packaging for it! I'm usually happy to devote time and resources 
to helping make Virtualmin work on other systems. I just don't have the time/resources to maintain more than the 
most popular server operating systems myself.

# See also

These are the tools the shell script uses to actually perform the installation and configuration. It sets up package repositories, installs the yum groups or the metapackages, and then uses Virtualmin-Config to perform the initial configuration steps, like turning on services, making service configuration changes, etc.

[Virtualmin-Config: a post-modern post-installation configuration tool](https://github.com/virtualmin/Virtualmin-Config)

[virtualmin-yum-groups: Package groups for CentOS and Fedora](https://github.com/virtualmin/virtualmin-yum-groups)

[virtualmin-lamp-stack-deb: Metapackage for the LAMP stack on Debian](https://github.com/virtualmin/virtualmin-lamp-stack-deb)

[virtualmin-lamp-stack-ubu: Metapackage for the LAMP stack on Ubuntu](https://github.com/virtualmin/virtualmin-lamp-stack-ubu)

[virtualmin-core-deb: Metapackage for the Virtualmin core packages](https://github.com/virtualmin/virtualmin-core-deb)
