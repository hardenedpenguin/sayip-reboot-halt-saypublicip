#!/usr/bin/perl

# sayip.pl - A script to announce the IP addresses of active network interfaces
# This script retrieves the IP addresses of all active network interfaces (excluding loopback)
# and uses Asterisk to play an audio file and announce the IP addresses associated with a specified node.
#
# Copyright (c) 2025 Jory A. Pratt, W5GLE <geekypenguin@gmail.com>

use strict;
use warnings;
use Net::Ifconfig::Wrapper;  # Module for network info
use lib '/usr/share/perl5';

# Constants for file paths
use constant {
    LOCAL_AUDIO_FILE => '/etc/asterisk/local/ip-address',
    SPEAKTEXT_SCRIPT => '/etc/asterisk/local/speaktext.pl',
    SLEEP_DURATION => 5,
};

my $node = shift @ARGV;
$node =~ /^\d+$/ || die "No valid node number supplied - usage: sayip.pl <node>\n";

system("asterisk -rx \"rpt localplay $node " . LOCAL_AUDIO_FILE . "\"") == 0 ||
    die "Failed to play audio for node $node: $!\n";

my $rhInfo = Net::Ifconfig::Wrapper::Ifconfig('list');

for my $interface (keys %$rhInfo) {
    next if $interface eq 'lo';
    my ($ip) = keys %{$rhInfo->{$interface}->{inet}};
    next unless $ip;
    
    if ($ip =~ /^(\d{1,3}\.){3}\d{1,3}$/) {
        sleep(SLEEP_DURATION);
        $ip =~ s/[^0-9.]//g;
        system(SPEAKTEXT_SCRIPT, $ip, $node) || warn "Failed to speak IP address $ip for node $node: $!\n";
    }
}
