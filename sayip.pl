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

# Check if a node number was supplied as a command-line argument
my $node = shift @ARGV;  # Get the first command-line argument
if (!defined $node || $node !~ /^\d+$/) {
    die "No valid node number supplied - usage: sayip.pl <node>\n";
}

# Play a local audio file associated with the node using Asterisk
my $result = system("asterisk -rx \"rpt localplay $node " . LOCAL_AUDIO_FILE . "\"");
if ($result != 0) {
    die "Failed to play audio for node $node: $!\n";
}

# Retrieve a list of active network interfaces
my $rhInfo = Net::Ifconfig::Wrapper::Ifconfig('list');  # Use the correct method to get interface info

# Iterate over each active network interface
foreach my $interface (keys %$rhInfo) {
    # Skip loopback interface
    next if $interface eq 'lo';

    # Get the IPv4 address from the hash reference
    my ($ip) = keys %{$rhInfo->{$interface}->{inet}};  # Get the first key from the inet hash
    next unless defined $ip;  # Skip if no IP is found

    # Ensure we are using only the IPv4 address
    if ($ip =~ m{^(\d{1,3}\.){3}\d{1,3}$}) {  # Simple regex to check for IPv4 format
        sleep(SLEEP_DURATION);  # Pause for a configurable duration

        # Use a script to speak the IP address and node number
        $result = system(SPEAKTEXT_SCRIPT, $ip, $node);
        if ($result != 0) {
            warn "Failed to speak IP address $ip for node $node: $!\n";
        }
    }
}
