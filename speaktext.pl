#!/usr/bin/perl

# speaktext.pl - A script to convert text to speech using Asterisk
# This script takes a text input and a node number, converts the text to audio files,
# and plays them using the Asterisk system.
#
# Copyright (c) 2025 Jory A. Pratt, W5GLE <geekypenguin@gmail.com>

use strict;
use warnings;

# Define constants for file paths
my $ASTSND = '/usr/share/asterisk/sounds/en';  # Path to Asterisk sound files
my $LOCALSND = '/tmp/localmsg';  # Path for temporary audio file

sub speak {
    my ($text, $node) = @_;
    my $speaktext = lc($text);

    unlink "${LOCALSND}.ulaw";
    open my $fh, '>', "${LOCALSND}.ulaw" or die "Cannot open file ${LOCALSND}.ulaw: $!";

    for my $ch (split //, $speaktext) {
        if ($ch =~ /[A-Za-z_]/) {
            add_sound($fh, "letters/${ch}.ulaw");
        } elsif ($ch =~ /[0-9]/) {
            add_sound($fh, "digits/${ch}.ulaw");
        } elsif ($ch eq '.') {
            add_sound($fh, "letters/dot.ulaw");
        } elsif ($ch eq '-') {
            add_sound($fh, "letters/dash.ulaw");
        } elsif ($ch eq '=') {
            add_sound($fh, "letters/equals.ulaw");
        } elsif ($ch eq '/') {
            add_sound($fh, "letters/slash.ulaw");
        } elsif ($ch eq '!') {
            add_sound($fh, "letters/exclaimation-point.ulaw");
        } elsif ($ch eq '@') {
            add_sound($fh, "letters/at.ulaw");
        } elsif ($ch eq '$') {
            add_sound($fh, "letters/dollar.ulaw");
        } else {
            warn "Unsupported character: $ch\n";
        }
    }

    close $fh;
    system("asterisk -rx \"rpt localplay $node ${LOCALSND}\" >/dev/null 2>&1");
}

sub add_sound {
    my ($fh, $sound_file) = @_;
    my $full_path = "${ASTSND}/$sound_file";
    if (-f $full_path) {
        print $fh `cat "$full_path"`;
    } else {
        warn "Warning: Sound file $full_path not found, skipping...\n";
    }
}

@ARGV == 2 || die "Usage: speaktext.pl \"abc123\" node#\n";
$ARGV[0] !~ /[^A-Za-z0-9._\-\/!@$]/ || die "Input text contains unsupported characters.\n";

speak($ARGV[0], $ARGV[1]);
sleep 3;
unlink "${LOCALSND}.ulaw";
