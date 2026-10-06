#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use File::Temp qw(tempdir);
use Test::More;

# Exercise the real hostname-selection block with setters replaced by traces.
# The full installer and its system-changing setup never run in these fixtures.
open my $source_file, '<', 'virtualmin-install.sh' or die $!;
my $source = do { local $/; <$source_file> };
$source =~ /(# Check for a fully qualified hostname unless setting up repos\..*?)^# Insert the serial number/ms
    or die 'Missing hostname-selection block';
my $block = $1;
my $dir = tempdir(CLEANUP => 1);
open my $fixture, '>', "$dir/check.sh" or die $!;
print {$fixture} <<'SH';
mode=$1
forcehostname=$2
current=$3
setup_only=$4
lookup_status=$5
resolved=${6-$current}
static_status=${7-0}
setter_status=${8-0}
log_debug () { :; }
# hostname([option]) distinguishes the current name from the resolved name.
hostname () {
    if [ "${1-}" = -f ]; then
        # Simulate a DNS lookup, including failure or a different canonical name.
        printf '%s\n' "$resolved"
        return "$lookup_status"
    else
        # Reading the current hostname does not depend on DNS.
        printf '%s\n' "$current"
    fi
}
# hostnamectl([option]) can fail independently of the current hostname.
hostnamectl () { printf '%s\n' "$current"; return "$static_status"; }
# fatal(message) makes a failed mapping observable without installer cleanup.
fatal () { printf 'FATAL:%s\n' "$1"; exit 1; }
# Trace which setter is selected, including whether it receives an argument.
set_hostname () { printf 'SET:%s\n' "$*"; return "$setter_status"; }
set_hosts_entry () { printf 'HOSTS:%s\n' "$1"; return "$setter_status"; }
# is_fully_qualified(name) selects the full-install prompt or existing-name path.
is_fully_qualified () { case $1 in *.*) return 0 ;; *) return 1 ;; esac; }
SH
print {$fixture} $block;
close $fixture or die $!;

# run_fixture(shell, args...) runs the fixture and captures its trace and status.
# Args select mode, forced/current names, setup, and optional lookup/setter results.
sub run_fixture {
    my ($shell, @args) = @_;
    open my $output, '-|', $shell, "$dir/check.sh", @args or die $!;
    my $trace = do { local $/; <$output> };
    close $output;
    return { trace => $trace // '', status => $? >> 8 };
}

# run_case(shell, args...) returns the trace of a successful fixture run.
sub run_case {
    my $result = run_fixture(@_);
    die "Hostname block failed with status $result->{status}" if $result->{status};
    return $result->{trace};
}

my @shells = qw(sh bash);
push @shells, 'dash' if grep { -x "$_/dash" } split /:/, $ENV{PATH};
for my $shell (@shells) {
    # Minimal installs retain their hostname even when --hostname is supplied.
    for my $forced ('', 'host', 'new.example.com') {
        is(run_case($shell, 'mini', $forced, 'current', '', 0), "HOSTS:current\n",
           "$shell minimal install keeps the current short name with '$forced'");
        is(run_case($shell, 'mini', $forced, 'current.example.com', '', 0),
           "HOSTS:current.example.com\n",
           "$shell minimal install keeps the current FQDN with '$forced'");
    }
    # Placeholder hostnames must not become primary-address mappings.
    for my $name ('', 'localhost', 'localhost.localdomain') {
        is(run_case($shell, 'mini', '', $name, '', 0), '',
           "$shell minimal install skips '$name'");
    }
    is(run_case($shell, 'mini', '', 'current', '', 1), "HOSTS:current\n",
       "$shell minimal install maps the current name when DNS lookup fails");
    is(run_case($shell, 'mini', '', 'current', '', 0, 'canonical.example.com'),
       "HOSTS:current\n", "$shell minimal install maps the current name instead of a DNS alias");
    is(run_case($shell, 'mini', '', 'current', '', 1, '', 1), "HOSTS:current\n",
       "$shell minimal install needs neither DNS nor hostnamectl");
    # Full installs still pass forced names to the existing FQDN validator.
    for my $forced ('host', 'new.example.com') {
        is(run_case($shell, 'full', $forced, 'current', '', 0), "SET:$forced\n",
           "$shell full install forwards '$forced' to set_hostname");
    }
    is(run_case($shell, 'full', '', 'current', '', 0), "SET:\n",
       "$shell full install prompts for an FQDN when the name is short");
    is(run_case($shell, 'full', '', 'current.example.com', '', 0),
       "SET:current.example.com\n", "$shell full install keeps an existing FQDN");
    is(run_case($shell, 'full', '', 'current.example.com', '', 1, ''),
       "SET:current.example.com\n", "$shell full install retains its static-hostname fallback");
    # A required hosts entry must not fail without stopping either install mode.
    for my $mode (qw(mini full)) {
        my $result = run_fixture($shell, $mode, '', 'current.example.com',
                                 '', 0, 'current.example.com', 0, 7);
        is($result->{status}, 1, "$shell $mode install stops when the hosts update fails");
        like($result->{trace}, qr/FATAL:Failed to configure the hostname entry in \/etc\/hosts\./,
             "$shell $mode install explains the hosts update failure");
    }
    # Repository setup must not configure hostnames in either mode.
    for my $mode (qw(mini full)) {
        is(run_case($shell, $mode, 'new.example.com', 'current', 1, 0), '',
           "$shell repository setup skips hostname changes in $mode mode");
    }
}
done_testing();
