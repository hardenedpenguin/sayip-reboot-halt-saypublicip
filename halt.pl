#!/usr/bin/perl

# halt.pl - A script to notify via voice and halt the system

use strict;
use warnings;

# Check if a node number (or any argument) was supplied as a command-line argument
my $node = shift @ARGV;  # Get the first command-line argument

# If an argument is provided, play the halt audio message using Asterisk
if (defined $node && $node ne '') {
    my $result = system("asterisk -rx \"rpt localplay $node /etc/asterisk/local/halt\"");
    if ($result != 0) {
        die "Failed to play halt audio for node $node: $!\n";
    }
    
    sleep(10);  # Sleep for 10 seconds
}

# Power off the system
system("/usr/sbin/poweroff");