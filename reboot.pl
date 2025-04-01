#!/usr/bin/perl

# reboot.pl - A script to notify via voice and reboot the system
# This script plays a voice message using Asterisk and then reboots the system.
#
# Copyright (c) 2025 Jory A. Pratt, W5GLE <geekypenguin@gmail.com>

use strict;
use warnings;

# Check if a node number (or any argument) was supplied as a command-line argument
my $node = shift @ARGV;  # Get the first command-line argument

# If an argument is provided, play the reboot audio message using Asterisk
if (defined $node && $node ne '') {
    my $result = system("asterisk -rx \"rpt localplay $node /etc/asterisk/local/reboot\"");
    if ($result != 0) {
        die "Failed to play reboot audio for node $node: $!\n";
    }
    
    sleep(10);  # Sleep for 10 seconds
}

# Power off the system
system("/usr/sbin/reboot");