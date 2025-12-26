#!/usr/bin/perl

# reboot.pl - A script to notify via voice and reboot the system
# This script plays a voice message using Asterisk and then reboots the system.
#
# Copyright (c) 2025 Jory A. Pratt, W5GLE <geekypenguin@gmail.com>

use strict;
use warnings;

my $node = shift @ARGV;
if ($node && $node =~ /^\d+$/) {
    system("asterisk -rx \"rpt localplay $node /etc/asterisk/local/reboot\" >/dev/null 2>&1");
    sleep 10;
}
system("/usr/sbin/reboot");