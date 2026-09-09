#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;

use Cwd qw(getcwd);
use File::Copy qw(copy);
use File::Temp qw(tempdir);
use Test::More;

sub shell_quote {
    my ($value) = @_;
    $value =~ s/'/'"'"'/g;
    return "'$value'";
}

sub run_installer {
    my ( $shell, @args ) = @_;
    my $args = join ' ', map { shell_quote($_) } @args;
    my $out = `$shell virtualmin-install.sh $args 2>&1`;
    return ( $? >> 8, $out );
}

for my $shell (qw(sh dash)) {
    # Invalid sizes are rejected before installation starts
    for my $size (qw(bogus 2T 9999999M 999999999999G -1 1.5G M), '%s') {
        my ( $status, $out ) = run_installer( $shell, '--swap', $size );
        isnt( $status, 0, "$shell rejects $size" );
        like( $out, qr/^Invalid swap size: \Q$size\E/m,
              "$shell preserves $size in the diagnostic" );
    }

    # Conflicting swap flags are mutually exclusive
    my ( $status, $out ) = run_installer(
        $shell, '--swap', '1G', '--no-swap'
    );
    isnt( $status, 0, "$shell rejects conflicting flags" );
    like( $out, qr/mutually exclusive/, "$shell explains the conflict" );

    # Leading zeros must be decimal; dash otherwise interprets 08 as octal
    ( $status, $out ) = run_installer(
        $shell, '--swap', '08G', '--version'
    );
    is( $status, 0, "$shell accepts a leading-zero size" );
    like( $out, qr/^\d+(?:\.\d+)+\s*$/,
          "$shell continues to version output" );
}

# Removal, units, bounds, and missing values are handled before startup.
for my $shell (qw(sh dash)) {
    for my $size (qw(0 000 512 1537K 08G 512mb 1023G)) {
        my ($status, $out) = run_installer($shell, '--swap', $size, '--version');
        is($status, 0, "$shell accepts $size");
    }
    my ($status, $out) = run_installer($shell, '--swap');
    isnt($status, 0, "$shell rejects a missing size");
    like($out, qr/requires a size/, "$shell diagnoses the missing argument");
    for my $mode (qw(--setup --uninstall --connect)) {
        ($status, $out) = run_installer($shell, '--swap-only', $mode, 'ipv4');
        isnt($status, 0, "$shell rejects incompatible $mode");
    }
    ($status, $out) = run_installer($shell, '--swap-only', '--no-swap');
    is($status, 0, "$shell permits a standalone opt-out");
    like($out, qr/System swap left unchanged/, "$shell reports no changes");
}

# Explicit swap controls must not be silently ignored with an older slib
my $tempdir = tempdir( CLEANUP => 1 );
copy( 'virtualmin-install.sh', "$tempdir/virtualmin-install.sh" )
    or die "Cannot copy installer: $!";
open my $slib, '>', "$tempdir/slib.sh" or die "Cannot create slib stub: $!";
print {$slib} <<'SH';
get_distro () { return 0; }
serial_ok () { return 0; }
log_error () { printf '[ERROR] %s\n' "$1"; }
# Stop at the first log message after the compatibility gate, before installation.
log_info () {
  case "$1" in
    'Installation log is written to '*) printf 'PAST_COMPATIBILITY_GATE:%s\n' "$1"; exit 0 ;;
  esac
}
SH
close $slib;

my $cwd = getcwd();
chdir $tempdir or die "Cannot enter $tempdir: $!";
for my $shell (qw(sh dash)) {
    for my $args ( [ '--swap', '512M' ], [ '--swap-only', '--swap', '512M' ] ) {
        my ( $status, $out ) = run_installer(
            $shell, '--force-reinstall', '--no-banner', @{$args}
        );
        isnt( $status, 0, "$shell rejects unsupported @{$args}" );
        like( $out, qr/does not support the requested swap option/,
              "$shell explains the slib version mismatch" );
    }
    # Without any swap flag the message must not mention a requested option
    my ( $status, $out ) = run_installer( $shell, '--force-reinstall', '--no-banner' );
    isnt( $status, 0, "$shell rejects implicit swap management with an old slib" );
    like( $out, qr/does not support swap management.*\n.*--no-swap/,
          "$shell points implicit users at --no-swap" );
    ( $status, $out ) = run_installer( $shell, '--force-reinstall', '--no-banner', '--no-swap' );
    is( $status, 0, "$shell opt-out works with an old slib" );
    like( $out, qr/PAST_COMPATIBILITY_GATE:Installation log is written to/,
          "$shell opt-out passes the actual compatibility gate" );
}
chdir $cwd or die "Cannot restore $cwd: $!";

# Swap-only stops before the install lifecycle and highlights only swap sizes.
open $slib, '>', "$tempdir/slib.sh" or die $!;
print {$slib} <<'SH';
SLIB_SWAP_API=2
YELLOW='<yellow>'
NORMAL='<normal>'
get_distro () { echo UNEXPECTED_DISTRO; exit 98; }
serial_ok () { echo UNEXPECTED_LICENSE; exit 98; }
log_error () { printf 'ERROR:%s\n' "$1"; printf 'ERROR:%s\n' "$1" >> "$LOG_PATH"; }
log_info () { printf 'INFO:%s\n' "$1"; printf 'INFO:%s\n' "$1" >> "$LOG_PATH"; }
log_success () { printf 'SUCCESS:%s\n' "$1"; printf 'SUCCESS:%s\n' "$1" >> "$LOG_PATH"; }
swap_plan () {
  swap_action=create
  case "$SWAP_TEST_CASE" in
    preflight_failure) swap_error='Preflight failed.'; return 1 ;;
    unchanged) swap_action=none ;;
  esac
  return 0
}
swap_plan_message () { echo 'The swap space will be created with a size of 64 MiB.'; }
swap_setup () {
  echo SWAP_ONLY_EXECUTED >> "$RUN_LOG"
  if [ "$SWAP_TEST_CASE" = execution_failure ]; then log_error 'Swap operation failed.'; return 1; fi
}
yesno () { printf '\n'; [ "$SWAP_TEST_CASE" != cancelled ]; }
SH
close $slib;
chdir $tempdir or die $!;
for my $shell (qw(sh dash)) {
    my ($status, $out) = run_installer($shell, '--swap-only', '--swap', '64M', '--yes');
    is($status, 0, "$shell executes swap-only independently of installation");
    like($out, qr/The swap space will be created with a size of <yellow>64 MiB<normal>\./, "$shell highlights only the swap size");
    # Earlier Linux-only startup probes can warn when these fixtures run on macOS.
    like($out, qr/^INFO:Swap setup log is written to [^\n]+\nINFO:Started swap setup\nINFO:[^\n]+\nSUCCESS:Swap setup completed successfully\.\n\z/m,
         "$shell uses the setup log style without extra blank lines");
    open my $log, '<', "$tempdir/virtualmin-swap.log" or die $!;
    my $logged = do { local $/; <$log> };
    close $log;
    like($logged, qr/SWAP_ONLY_EXECUTED/, "$shell invokes swap execution");
    like($logged, qr/^INFO:The swap space will be created with a size of 64 MiB\.$/m,
         "$shell records the plain plan in the announced log");
    like($logged, qr/^SUCCESS:Swap setup completed successfully\.$/m, "$shell logs completion");
    unlike($logged, qr/<yellow>|<normal>/, "$shell keeps display colors out of the log");
    unlike($out, qr/UNEXPECTED_/, "$shell avoids distro and license setup");

    # Neither failed preflight nor failed execution can announce success.
    for my $failure (qw(preflight_failure execution_failure)) {
        local $ENV{SWAP_TEST_CASE} = $failure;
        ($status, $out) = run_installer($shell, '--swap-only', '--swap', '64M', '--yes');
        isnt($status, 0, "$shell reports $failure");
        like($out, qr/^ERROR:.*failed\./m, "$shell shows the failure as an error");
        like($out, qr/^ERROR:.*--no-swap/m, "$shell retains the opt-out advice");
        unlike($out, qr/^SUCCESS:/m, "$shell never announces success after $failure");
    }

    # A no-op completes successfully; declining confirmation only cancels.
    for my $scenario (qw(unchanged cancelled)) {
        local $ENV{SWAP_TEST_CASE} = $scenario;
        ($status, $out) = run_installer($shell, '--swap-only', '--swap', '64M');
        is($status, 0, "$shell handles $scenario without an error");
        like($out, $scenario eq 'unchanged' ? qr/SUCCESS:System swap left unchanged\./
             : qr/INFO:Swap setup cancelled; system swap left unchanged\./,
             "$shell explains $scenario");
        open $log, '<', "$tempdir/virtualmin-swap.log" or die $!;
        $logged = do { local $/; <$log> };
        close $log;
        unlike($logged, qr/SWAP_ONLY_EXECUTED/, "$shell does not execute swap for $scenario");
    }
}
chdir $cwd or die $!;

# The ordinary pre-installation message highlights the size within its paragraph.
open my $installer, '<', 'virtualmin-install.sh' or die $!;
my $source = do { local $/; <$installer> };
$source =~ /(install_msg\(\) \{.*?^\})/ms or die 'Missing install_msg';
open my $preview, '>', "$tempdir/preview.sh" or die $!;
print {$preview} $1, "\n";
print {$preview} <<'SH';
SLIB_SWAP_API=2
YELLOW='<yellow>'
NORMAL='<normal>'
skipyesno=1
disk_space_required=2
mode=full
bundle=LAMP
tput () { echo 40; }
swap_plan () { swap_action=create; }
swap_plan_message () { echo 'The swap space will be created with a size of 64 MiB.'; }
install_msg
SH
close $preview;
for my $shell (qw(sh dash)) {
    my $out = `$shell '$tempdir/preview.sh'`;
    is($? >> 8, 0, "$shell renders the installation preview");
    like($out, qr/The swap\s+space will be created with a size of <yellow>64 MiB<normal>\./, "$shell highlights only the pre-install swap size");
}

# Exercise the actual installation gate without running later system changes.
$source =~ /(swap_abort\(\) \{.*?^\})/ms or die 'Missing swap_abort';
my $abort = $1;
$source =~ /(# Check memory, and set up swap.*?)(?=# Check for localhost)/s
    or die 'Missing memory gate';
my $gate = $1;
open my $failure, '>', "$tempdir/failure.sh" or die $!;
print {$failure} $abort, "\n", <<'SH';
mode=full
disk_space_required=2
swapsize=$1
noswap=$2
setup_only=$3
log_error () { printf 'ERROR:%s\n' "$1"; }
memory_ok () { echo SWAP_ATTEMPTED; return 1; }
SH
print {$failure} $gate, "\nprintf 'INSTALLATION_CONTINUES\\n'\n";
close $failure;
for my $shell (qw(sh dash)) {
    for my $size ('', '2048') {
        my $out = `$shell '$tempdir/failure.sh' '$size' '' ''`;
        isnt($? >> 8, 0, "$shell stops installation after a swap failure (size=$size)");
        like($out, qr/ERROR:.*--no-swap/, "$shell explains how to opt out");
        unlike($out, qr/INSTALLATION_CONTINUES/, "$shell never reaches installation after failure");
        like($out, qr/instead of --swap/, "$shell explains replacing an explicit size") if length $size;
    }
    for my $guard (['1', ''], ['', '1']) {
        my $out = `$shell '$tempdir/failure.sh' '' '$guard->[0]' '$guard->[1]'`;
        is($? >> 8, 0, "$shell preserves the swap opt-out/setup bypass");
        unlike($out, qr/SWAP_ATTEMPTED/, "$shell bypass never attempts swap");
    }
}

done_testing();
