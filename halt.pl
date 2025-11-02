#!/usr/bin/perl

# halt.pl - A script to notify via voice and halt the system
# This script plays a voice message using Asterisk and then halts the system.
#
# Copyright (c) 2025 Jory A. Pratt, W5GLE <geekypenguin@gmail.com>

use strict;
use warnings;

my $node = shift @ARGV;
if ($node) {
    system("asterisk -rx \"rpt localplay $node /etc/asterisk/local/halt\" >/dev/null 2>&1");
    sleep 10;
}
system("/usr/sbin/poweroff");