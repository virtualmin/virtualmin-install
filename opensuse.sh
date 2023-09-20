#!/bin/sh
# Copyright 2005-2023 Virtualmin, Inc.
# virtualmin-install.sh - openSUSE module
# shellcheck disable=SC2154 disable=SC2034 disable=SC2086

# Fix openSUSE pitfalls
opensuse_poststack() {
    # Install Virtualmin Config package manually
    # as it currently fails with false positive error
    package_virtualmin_config=$(dnf download virtualmin-config)
    package_virtualmin_config_name=$(echo "$package_virtualmin_config" | grep -o 'virtualmin-config[^ ]*.rpm')
    rpm -U --nodeps --replacepkgs --replacefiles --quiet $package_virtualmin_config_name
    # Create symlink to known @INC to where Virtualmin Config is actually is
    ln -sf /usr/share/perl5/vendor_perl/Virtualmin /usr/lib/perl5/site_perl
    # Remove downloaded package
    rm -f $package_virtualmin_config_name
    # Now check which packages are missing and install them manually using package manager
    install_group_opts_loud=$(echo $install_group_opts | sed 's/ --quiet//g')
    virtualmin_group_missing_cmd="$install_cmd $install_group_opts_loud $rhgroup"
    virtualmin_group_missing_try=$(eval $virtualmin_group_missing_cmd 2>&1)
    # Extract missing package list
    virtualmin_group_missing=$(echo "$virtualmin_group_missing_try" | grep -o '"[^"]\+"' | tr -d '"' | tr '\n' ' ')
    # PHP packages are actually named php8-* in openSUSE
    virtualmin_group_missing=$(echo "$virtualmin_group_missing" | sed 's/php-/php8-/g')
    # The package fail2ban-firewalld is named fail2ban in openSUSE
    virtualmin_group_missing=$(echo "$virtualmin_group_missing" | sed 's/fail2ban-firewalld/fail2ban/g')
    # The package mod_fcgid is named apache2-mod_fcgid in openSUSE
    virtualmin_group_missing=$(echo "$virtualmin_group_missing" | sed 's/mod_fcgid/apache2-mod_fcgid/g')
    # AppArmor should either be configured to allow /var/php-fpm for
    # PHP-FPM sockets or disabled completely
    systemctl stop apparmor.service
    systemctl disable apparmor.service
    systemctl mask apparmor.service
    # Swap pre-installed posfix for postfix-bdb-lmdb
    $install_cmd -y swap --allowerasing postfix postfix-bdb-lmdb
    # Install missing packages that we extracted earlier
    $install --skip-broken $virtualmin_group_missing cyrus-sasl-saslauthd
    # There is no AWStats package in openSUSE
    $install_cmd -y remove wbm-virtualmin-awstats
    # Add allow_vendor_change=True to /etc/dnf/dnf.conf unless it's already there
    grep -qxF 'allow_vendor_change=True' /etc/dnf/dnf.conf || echo "allow_vendor_change=True" >> /etc/dnf/dnf.conf
}
run_ok "opensuse_poststack" "Installing Virtualmin $vm_version missing stack packages"
# Don't show false positively skipped packages
noskippedpackagesforce=1
# Fix to skip configuring AWStats as it's not available in openSUSE
virtualmin_config_system_excludes=" --exclude AWStats"
