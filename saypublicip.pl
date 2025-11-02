#!/usr/bin/perl

# saypublicip.pl - A script to announce the public IP address of the system
# This script retrieves the public IP address using a curl command and uses Asterisk to play an audio file
# announcing the public IP address associated with a specified node.
#
# Copyright (c) 2025 Jory A. Pratt, W5GLE <geekypenguin@gmail.com>

use strict;
use warnings;

# Constants
my $IP_URL = 'https://api.ipify.org';  # Primary URL to fetch public IP address
my $IP_URL_FALLBACK = 'https://ifconfig.me';  # Fallback URL if primary fails
my $AUDIO_PATH = '/etc/asterisk/local/public-ip-address';
my $SPEAK_SCRIPT = '/etc/asterisk/local/speaktext.pl';

my $node = shift @ARGV;
@ARGV == 0 || die "Usage: $0 <node_number>\n";
$node =~ /^\d+$/ || die "Invalid node number format. Please provide a numeric node identifier.\n";

my $ip = `curl -s --max-time 10 --connect-timeout 5 $IP_URL 2>&1`;
if ($ip !~ /(\d{1,3}\.){3}\d{1,3}/) {
    $ip = `curl -s --max-time 10 --connect-timeout 5 $IP_URL_FALLBACK 2>&1`;
    $ip =~ /(\d{1,3}\.){3}\d{1,3}/ || die "Failed to retrieve a valid public IP address from both sources\n";
}

system("asterisk -rx \"rpt localplay $node $AUDIO_PATH\" >/dev/null 2>&1");

sleep 5;
chomp $ip;
$ip =~ s/[^0-9.]//g;
system($SPEAK_SCRIPT, $ip, $node);
