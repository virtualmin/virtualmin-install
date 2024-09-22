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

The **Grade A** systems currently supported by install script are:

    Red Hat Enterprise Linux and derivatives
      - RHEL 8 and 9 on x86_64
      - Alma and Rocky 8 and 9 on x86_64
      - CentOS 7 on x86_64 (no longer recommended)
      
    Debian Linux and derivatives
      - Debian 10, 11 and 12 on i386 and amd64
      - Ubuntu 20.04 LTS, 22.04 LTS and 24.04 LTS on i386 and amd64

The _Grade B_ systems currently supported by install script are:

    Red Hat Enterprise Linux and derivatives
      - Fedora Server 38 and above on x86_64
      - CentOS Stream 8 and 9 on x86_64
      - Oracle Linux 8 and 9 on x86_64
      - CloudLinux 8 and 9 on x86_64
      - Amazon Linux 2023 and above on x86_64
  
    Debian Linux and derivatives
      - Kali Linux Rolling 2023 and above on x86_64

We strongly recommend you use the latest version of your preferred **Grade A** supported distribution. The latest release gets the most active testing and bug fixing.

# How to run it

**Never run the install script on anything other than a freshly installed OS. It is for installation, not upgrading.**

## Upstream Version

Download it to your server, and run it as _`root`_ (yes, it has to run as _`root`_, this is systems management software).

    # wget -O virtualmin-install.sh https://raw.githubusercontent.com/virtualmin/virtualmin-install/master/virtualmin-install.sh
    # /bin/sh virtualmin-install.sh

Note that if you have Virtualmin Professional, the process is a little different (or you have to edit the script to add your serial number and key to the `SERIAL` and `KEY` variables on lines 19 and 20). You can retrieve your license information from the [My Account ⇾ Software Licenses](https://www.virtualmin.com/account/software-licenses/) page at Virtualmin website. If you don't have Pro but want to get it, visit [Virtualmin Shop](https://www.virtualmin.com/product-category/virtualmin).

Please file tickets, either here or at [Virtualmin Forum](https://forum.virtualmin.com), about bugs you find.

# How to use it in your own project

The Virtualmin install script is highly customizable and includes various hooks that can be inserted at any stage of the installation process. If you're integrating the script into your own project, you can use these hooks to inject custom code, add new phases, or control the text displayed to the user throughout the installation.

## Usage example for your project in a wrapper script
```sh
hook__usage() {
  # If defined, it will override the default usage message
  :
}

hook__parse_args() {
  # If defined, it will override the default argument parsing, and will not
  # parse default arguments if this hook is defined, relying on the custom
  # code to parse the arguments and set default values
  :
}

hook__install_msg() {
  # If defined, it will override the default welcome message
  :
}

pre_hook__install_msg() {
  # If defined, it will inject a message before the default welcome message
  :
}

post_hook__install_msg() {
  # If defined, it will inject a message after the default welcome message
  :
}

hook__os_unstable_pre_check() {
  # If defined, it will override the default pre-check message for unstable OS
  :
}

pre_hook__os_unstable_pre_check() {
  # If defined, it will inject a message before the default pre-check
  # message for unstable OS
  :
}

post_hook__os_unstable_pre_check() {
  # If defined, it will inject a message after the default pre-check
  # message for unstable OS
  :
}

hook__preconfigured_system_msg() { 
  # If defined, it will override the default system message about
  # pre-installed software
  :
}

pre_hook__preconfigured_system_msg() {
  # If defined, it will inject a message before the default system
  # message about pre-installed software
  :
}

post_hook__preconfigured_system_msg() {
  # If defined, it will inject a message after the default system
  # message about pre-installed software
  :
}

hook__already_installed_msg() {
  # If defined, it will override the default message about already
  # installed Virtualmin
  :
}

pre_hook__already_installed_msg() {
  # If defined, it will inject a message before the default message
  # about already installed Virtualmin
  :
}

post_hook__already_installed_msg() {
  # If defined, it will inject a message after the default message
  # about already installed Virtualmin
  :
}

hook__already_installed_block() {
  # If defined, it will override the default block message about
  # installed Virtualmin
  :
}

pre_hook__already_installed_block() {
  # If defined, it will inject a message before the default block message
  # about already installed Virtualmin
  :
}

post_hook__already_installed_block() {
  # If defined, it will inject a message after the default block message
  # about already installed Virtualmin
  :
}

hook__phases_all_pre() {
  # If defined, it will run before all phases
  :
}

hook__phase1_pre() {
  # If defined, it will run before the default phase 1
  :
}

hook__phase1_post() {
  # If defined, it will run after the default phase 1
  :
}

hook__phase2_pre() {
  # If defined, it will run before the default phase 2
  :
}

hook__phase2_post() {
  # If defined, it will run after the default phase 2
  :
}

hook__phase3_pre() {
  # If defined, it will run before the default phase 3
  :
}

hook__phase3_post() {
  # If defined, it will run after the default phase 3
  :
}

hook__phase4_pre() {
  # If defined, it will run before the default phase 4
  :
}

hook__phase4_post() {
  # If defined, it will run after the default phase 4
  :
}

hook__phases_all_post() {
  # If defined, it will run after all phases
  :
}

hook__clean_pre() {
  # If defined, it will run before the cleanup phase
  :
}

hook__clean_post() {
  # If defined, it will run after the cleanup phase
  :
}

hook__post_install_message() {
  # If defined, it will override the default post-install message
  :
}

pre_hook__post_install_message() {
  # If defined, it will inject a message before the default post-install message
  :
}

post_hook__post_install_message() {
  # If defined, it will inject a message after the default post-install message
  :
}

hook__phases_pre() {
  # If defined, it will run before the custom phases start
  :
}

hook__phases_post() {
  # If defined, it will run after the custom phases end
  :
}

# Override the default log file name
install_log_file_name=combined-install.log
export install_log_file_name

# If defined, it will override the default number of
# phases for the use in custom phases (default is 4)
phases_total=6
export phases_total

# If defined, it will run after the default phases to add additional
# stages and their commands with descriptions separated by tabs
hooks__phases='
5	Extra Installation	command-1	Command 1 description
5	Extra Installation	command-2	Command 2 description
5	Extra Installation	command-3	Command 3 description
6	Extra Configuration	config-command-1	Config Command 1 description
6	Extra Configuration	config-command-2	Config Command 2 description
'
export hooks__phases
```

# How to contribute

Wrap your head around how `virtualmin-install.sh` does its job (mostly by setting up package repositories and installed _metapackages_ or _yum_-groups). Ask questions if you're not sure what's going on.

Pick your favorite distro or OS, and start coding and packaging for it! I'm usually happy to devote time and resources to helping make Virtualmin work on other systems. I just don't have the time/resources to maintain more than the most popular server operating systems myself.

# See also

These are the tools the shell script uses to actually perform the installation and configuration. It sets up package repositories, installs the _yum_-groups or the _metapackages_, and then uses Virtualmin-Config to perform the initial configuration steps, like turning on services, making service configuration changes, etc.

[Virtualmin-Config: a post-modern post-installation configuration tool](https://github.com/virtualmin/Virtualmin-Config)

[virtualmin-yum-groups: Package groups for CentOS and Fedora](https://github.com/virtualmin/virtualmin-yum-groups)

[virtualmin-lamp-stack-ubu: Metapackage for the LAMP stack on Ubuntu](https://github.com/virtualmin/virtualmin-lamp-stack-ubu)

[virtualmin-core-deb: Metapackage for the Virtualmin core packages](https://github.com/virtualmin/virtualmin-core-deb)
