#!/usr/bin/perl

# saypublicip.pl - A script to announce the public IP address of the system
# This script retrieves the public IP address using a curl command and uses Asterisk to play an audio file
# announcing the public IP address associated with a specified node.
#
# Copyright (c) 2025 Jory A. Pratt, W5GLE <geekypenguin@gmail.com>

use strict;
use warnings;

# Constants
my $IP_URL = 'https://api.ipify.org';  # Updated URL to fetch public IP address
my $AUDIO_PATH = '/etc/asterisk/local/public-ip-address';
my $SPEAK_SCRIPT = '/etc/asterisk/local/speaktext.sh';

# Ensure the node number is provided as the only argument
if (@ARGV != 1) {
    die "Usage: $0 <node_number>\n";
}

# Define the node variable from the command-line argument
my $node = $ARGV[0];

# Validate the node number (example: numeric check)
if ($node !~ /^\d+$/) {
    die "Invalid node number format. Please provide a numeric node identifier.\n";
}

# Fetch the public IP address using curl
my $ip = `curl -s $IP_URL 2>&1`;  # Capture the output of the curl command

# Validate the IP address (basic check)
if ($ip !~ /(\d{1,3}\.){3}\d{1,3}/) {
    die "Failed to retrieve a valid public IP address: $ip\n";
}

# Play the public IP address audio message using Asterisk
my $result = system("asterisk -rx \"rpt localplay $node $AUDIO_PATH\"");
if ($result != 0) {
    die "Failed to play public IP audio for node $node: $!\n";
}

sleep(5);  # Sleep for 5 seconds

# Use a script to speak the public IP address and node number
$result = system($SPEAK_SCRIPT, $ip, $node);
if ($result != 0) {
    warn "Failed to speak public IP address $ip for node $node: $!\n";
}
