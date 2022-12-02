[![Build Status](https://travis-ci.com/virtualmin/virtualmin-install.svg?branch=master)](https://app.travis-ci.com/github/virtualmin/virtualmin-install)

# virtualmin-install
Shell script to perform a Virtualmin GPL or Professional installation

If you just want to install Virtualmin, go here and follow the instructions: [Virtualmin.com](https://www.virtualmin.com/download).

This repo is for people who want to read the source, contribute, help make the installer support other distros or operating systems, or make a customized installer.

# How it Works
The script relies on our software repositories on _software.virtualmin.com_ in order to function. You'll need internet access.

It sets up or downloads the software repository configuration file for your OS (`yum/dnf` on RHEL (Alma/Rocky/Oracle/CentOS/Fedora) or 
`apt-get` on Debian/Ubuntu), and runs the necessary commands to download and install all of the stuff needed for a
Virtualmin web hosting system. This is includes OS-standard packages or MySQL or MariaDB, Postfix, Dovecot, procmail,
Mailman, PHP, Python, Ruby, SpamAssassin, ClamAV, BIND, and many others. When no OS-standard package is available or
the standard package needs tweaks, we provide it in our repository and fetch it from there.

## Supported Operating Systems

The Grade A systems currently supported by install script are:

    Red Hat Enterprise Linux and derivatives
      - RHEL 8 and 9 on x86_64
      - Alma and Rocky 8 and 9 on x86_64
      - CentOS 7 on x86_64
      
    Debian Linux and derivatives
      - Debian 10 and 11 on i386 and amd64
      - Ubuntu 20.04 LTS and 22.04 LTS on i386 and amd64

The Grade B systems currently supported by install script are:

    Red Hat Enterprise Linux and derivatives
      - Fedora Server 36+ on x86_64
      - CentOS Stream 8 and 9 on x86_64
      - Oracle Linux 8 and 9 on x86_64
  
We strongly recommend you use the latest version of your preferred Grade A supported distribution. The latest release gets the most active testing and bug fixing.

# How to run it

**Never run the install script on anything other than a freshly installed OS. It is for installation, not upgrading.**

## Upstream Version

Download it to your server, and run it as _`root`_ (yes, it has to run as _`root`_, this is systems management software).

    # wget -O virtualmin-install.sh https://raw.githubusercontent.com/virtualmin/virtualmin-install/master/virtualmin-install.sh
    # /bin/sh virtualmin-install.sh

Note that if you have Virtualmin Professional, the process is a little different (or you have to edit the script to add your serial number and key to the `SERIAL` and `KEY` variables on lines 19 and 20). You can retrieve your license information from the [My Account ⇾ Software Licenses](https://www.virtualmin.com/account/software-licenses/) page at Virtualmin website. If you don't have Pro but want to get it, visit [Virtualmin Shop](https://www.virtualmin.com/product-category/virtualmin).

Please file tickets, either here or at [Virtualmin Forum](https://forum.virtualmin.com), about bugs you find.

# How to contribute

Wrap your head around how `install.sh` does its job (mostly by setting up package repositories and installed metapackages or `yum` groups). Ask questions if you're not sure what's going on.

Pick your favorite distro or OS, and start coding and packaging for it! I'm usually happy to devote time and resources to helping make Virtualmin work on other systems. I just don't have the time/resources to maintain more than the most popular server operating systems myself.

# See also

These are the tools the shell script uses to actually perform the installation and configuration. It sets up package repositories, installs the yum groups or the metapackages, and then uses Virtualmin-Config to perform the initial configuration steps, like turning on services, making service configuration changes, etc.

[Virtualmin-Config: a post-modern post-installation configuration tool](https://github.com/virtualmin/Virtualmin-Config)

[virtualmin-yum-groups: Package groups for CentOS and Fedora](https://github.com/virtualmin/virtualmin-yum-groups)

[virtualmin-lamp-stack-ubu: Metapackage for the LAMP stack on Ubuntu](https://github.com/virtualmin/virtualmin-lamp-stack-ubu)

[virtualmin-core-deb: Metapackage for the Virtualmin core packages](https://github.com/virtualmin/virtualmin-core-deb)
