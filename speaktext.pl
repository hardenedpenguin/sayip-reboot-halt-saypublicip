#!/usr/bin/perl

# speaktext.pl - A script to convert text to speech using Asterisk
# This script takes a text input and a node number, converts the text to audio files,
# and plays them using the Asterisk system.
#
# Copyright (c) 2025 Jory A. Pratt, W5GLE <geekypenguin@gmail.com>

use strict;  # Enforce strict variable declaration rules
use warnings;  # Enable warnings for potential issues
use File::Basename;  # Import File::Basename for file path manipulation

# Define constants for file paths
my $ASTSND = '/usr/share/asterisk/sounds/en';  # Path to Asterisk sound files
my $LOCALSND = '/tmp/localmsg';  # Path for temporary audio file

# Function to convert text to speech
sub speak {
    my ($text, $node) = @_;  # Get the text and node number from arguments
    my $SPEAKTEXT = lc($text);  # Convert text to lowercase for consistency
    my $SPEAKLEN = length($SPEAKTEXT);  # Get the length of the text
    my $COUNTER = 0;  # Initialize a counter for character processing

    # Remove any existing audio file
    unlink "${LOCALSND}.ulaw";

    # Open a new file for writing the audio data
    open my $fh, '>', "${LOCALSND}.ulaw" or die "Cannot open file: $!";

    # Process each character in the text
    while ($COUNTER < $SPEAKLEN) {
        $COUNTER++;  # Increment the counter
        my $CH = substr($SPEAKTEXT, $COUNTER - 1, 1);  # Get the current character

        # Determine the type of character and add the corresponding sound file
        if ($CH =~ /[A-Za-z_]/) {
            add_sound($fh, "letters/${CH}.ulaw");  # Add sound for letters
        } elsif ($CH =~ /[0-9]/) {
            add_sound($fh, "digits/${CH}.ulaw");  # Add sound for digits
        } elsif ($CH eq '.') {
            add_sound($fh, "letters/dot.ulaw");  # Add sound for dot
        } elsif ($CH eq '-') {
            add_sound($fh, "letters/dash.ulaw");  # Add sound for dash
        } elsif ($CH eq '=') {
            add_sound($fh, "letters/equals.ulaw");  # Add sound for equals
        } elsif ($CH eq '/') {
            add_sound($fh, "letters/slash.ulaw");  # Add sound for slash
        } elsif ($CH eq '!') {
            add_sound($fh, "letters/exclaimation-point.ulaw");  # Add sound for exclamation point
        } elsif ($CH eq '@') {
            add_sound($fh, "letters/at.ulaw");  # Add sound for at symbol
        } elsif ($CH eq '$') {
            add_sound($fh, "letters/dollar.ulaw");  # Add sound for dollar sign
        } else {
            warn "Unsupported character: $CH\n";  # Warn for unsupported characters
        }
    }

    # Close the file handle after writing all sounds
    close $fh;

    # Play the generated audio file using Asterisk
    my $result = system("asterisk -rx \"rpt localplay $node ${LOCALSND}\"");
    if ($result != 0) {
        warn "Failed to play audio: $!\n";  # Warn if the audio playback fails
    }
}

# Function to add sound data to the audio file
sub add_sound {
    my ($fh, $sound_file) = @_;  # Get the file handle and sound file name
    print $fh `cat "${ASTSND}/$sound_file"`;  # Append the sound data to the audio file
}

# Check command-line arguments for usage
if (@ARGV < 2) {
    die "Usage: speaktext.pl \"abc123\" node#\n";  # Provide usage instructions if arguments are missing
}

# Validate input text to ensure it contains only supported characters
if ($ARGV[0] =~ /[^A-Za-z0-9._\-\/!@$]/) {
    die "Input text contains unsupported characters.\n";  # Terminate if unsupported characters are found
}

# Call the speak function with the provided text and node number
speak($ARGV[0], $ARGV[1]);

# Sleep for a short duration to allow audio playback to complete
sleep(3);

# Clean up by removing the temporary audio file
unlink "${LOCALSND}.ulaw";
