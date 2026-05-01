#!/usr/bin/env ruby
# frozen_string_literal: true

#
# sayip.rb - Unified Ruby script for SayIP functionality
# Handles local IP, public IP, halt, and reboot
# Copyright (c) 2025-2026 Jory A. Pratt, W5GLE <geekypenguin@gmail.com>
#

require 'socket'
require 'net/http'
require 'uri'
require 'fileutils'
require 'tempfile'

# Constants
LOCAL_AUDIO_FILE = 'ip-address'
PUBLIC_AUDIO_PATH = 'public-ip-address'
HALT_AUDIO = 'halt'
REBOOT_AUDIO = 'reboot'
ASTSND = '/usr/share/asterisk/sounds/en'
SLEEP_DURATION = 5

# IP service URLs
IP_URL = 'https://api.ipify.org'
IP_URL_FALLBACK = 'https://ifconfig.me'

# Character to sound file mapping
CHAR_SOUND_MAP = {
  '.' => 'letters/dot.ulaw',
  '-' => 'letters/dash.ulaw',
  '=' => 'letters/equals.ulaw',
  '/' => 'letters/slash.ulaw',
  '!' => 'letters/exclaimation-point.ulaw',
  '@' => 'letters/at.ulaw',
  '$' => 'letters/dollar.ulaw'
}.freeze

# Validate node number
def validate_node(node)
  return false unless node
  # Keep it strictly numeric and reasonably bounded to avoid weird edge cases.
  node.match?(/^\d{1,10}$/)
end

# Execute asterisk command
def asterisk_cmd(cmd)
  system('asterisk', '-rx', cmd, out: File::NULL, err: File::NULL)
end

# Play audio file via Asterisk
def play_audio(node, audio_path)
  asterisk_cmd("rpt localplay #{node} #{audio_path}")
end

# Get local IP addresses from network interfaces
def get_local_ips
  ips = []
  
  # Try Socket.getifaddrs first (Ruby 2.1+, cross-platform)
  if Socket.respond_to?(:getifaddrs)
    Socket.getifaddrs.each do |ifaddr|
      next if ifaddr.name == 'lo'  # Skip loopback
      next unless ifaddr.addr
      next unless ifaddr.addr.ipv4?
      
      ip = ifaddr.addr.ip_address
      ips << ip if ip.match?(/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/)
    end
  end
  
  # Fallback: Parse 'ip addr show' output if Socket.getifaddrs didn't work
  if ips.empty?
    io = IO.popen(%w[ip addr show], err: File::NULL)
    io.each_line do |line|
      # Match lines like: inet 192.168.1.1/24 brd 192.168.1.255 scope global eth0
      if line =~ /inet\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\//
        ip = Regexp.last_match(1)
        # Skip loopback (127.0.0.1)
        ips << ip unless ip.start_with?('127.')
      end
    end
    io.close
  end
  
  ips.uniq
rescue StandardError => e
  warn "Warning: Error getting local IPs: #{e.message}"
  []
end

# Get public IP address via HTTP
def get_public_ip
  # Try primary URL
  begin
    uri = URI(IP_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10
    http.open_timeout = 5
    
    response = http.get(uri.request_uri)
    return nil unless response.is_a?(Net::HTTPSuccess)
    ip = response.body.strip
    
    return ip if ip.match?(/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/)
  rescue StandardError => e
    warn "Primary IP service failed: #{e.message}"
  end
  
  # Try fallback URL
  begin
    uri = URI(IP_URL_FALLBACK)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10
    http.open_timeout = 5
    
    response = http.get(uri.request_uri)
    return nil unless response.is_a?(Net::HTTPSuccess)
    ip = response.body.strip
    
    return ip if ip.match?(/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/)
  rescue StandardError => e
    warn "Fallback IP service failed: #{e.message}"
  end
  
  nil
end

# Add sound file to output
def add_sound(output_file, sound_file)
  full_path = File.join(ASTSND, sound_file)
  
  unless File.exist?(full_path)
    warn "Warning: Sound file #{full_path} not found, skipping..."
    return
  end
  
  File.open(full_path, 'rb') do |sound_fh|
    output_file.write(sound_fh.read)
  end
end

# Convert text to speech
def speak_text(text, node)
  speaktext = text.downcase
  
  Tempfile.create(['localmsg', '.ulaw'], '/tmp') do |tmp|
    tmp.binmode
    speaktext.each_char do |ch|
      sound_file = nil
      
      case ch
      when /[A-Za-z_]/
        sound_file = "letters/#{ch}.ulaw"
      when /[0-9]/
        sound_file = "digits/#{ch}.ulaw"
      else
        sound_file = CHAR_SOUND_MAP[ch]
      end
      
      if sound_file
        add_sound(tmp, sound_file)
      else
        warn "Unsupported character: #{ch}"
      end
    end
    tmp.flush
    tmp.fsync
    tmp.chmod(0o644) rescue nil

    # Play the generated audio (Asterisk expects path without extension)
    play_audio(node, tmp.path.sub(/\.ulaw$/, ''))

    # rpt localplay is async; keep the file around long enough for playback.
    # Worst-case here is small (IP address), so a conservative delay is fine.
    sleep 5
  end
end

# Announce local IP addresses
def say_local_ip(node)
  unless validate_node(node)
    $stderr.puts "No valid node number supplied - usage: #{$0} local <node>"
    exit 1
  end
  
  # Play intro audio
  play_audio(node, LOCAL_AUDIO_FILE)
  
  # Get and announce each IP
  ips = get_local_ips
  
  if ips.empty?
    warn "Warning: No local IP addresses found"
    return
  end
  
  ips.each do |ip|
    sleep(SLEEP_DURATION)
    speak_text(ip, node)
  end
end

# Announce public IP address
def say_public_ip(node)
  unless validate_node(node)
    $stderr.puts "Usage: #{$0} public <node_number>"
    exit 1
  end
  
  ip = get_public_ip
  
  unless ip
    $stderr.puts "Failed to retrieve a valid public IP address from both sources"
    exit 1
  end
  
  # Play intro audio
  play_audio(node, PUBLIC_AUDIO_PATH)
  
  sleep 5
  speak_text(ip, node)
end

# Halt the system
def halt_system(node)
  if validate_node(node)
    play_audio(node, HALT_AUDIO)
    sleep 10
  end
  
  exec('/usr/sbin/poweroff')
end

# Reboot the system
def reboot_system(node)
  if validate_node(node)
    play_audio(node, REBOOT_AUDIO)
    sleep 10
  end
  
  exec('/usr/sbin/reboot')
end

# Main command dispatcher
def main
  action = ARGV.shift
  
  # Map short arguments to long form
  action_map = {
    'l' => 'local',
    'p' => 'public',
    'h' => 'halt',
    'r' => 'reboot'
  }
  
  action = action_map[action] if action && action.length == 1
  
  case action
  when 'local'
    node = ARGV.shift
    say_local_ip(node)
  when 'public'
    node = ARGV.shift
    say_public_ip(node)
  when 'halt'
    node = ARGV.shift
    halt_system(node)
  when 'reboot'
    node = ARGV.shift
    reboot_system(node)
  else
    $stderr.puts "Usage: #{$0} <action> [arguments]"
    $stderr.puts ""
    $stderr.puts "Actions (long form):"
    $stderr.puts "  local <node>      - Announce local IP addresses"
    $stderr.puts "  public <node>     - Announce public IP address"
    $stderr.puts "  halt <node>       - Halt the system (with audio notification)"
    $stderr.puts "  reboot <node>     - Reboot the system (with audio notification)"
    $stderr.puts ""
    $stderr.puts "Actions (short form):"
    $stderr.puts "  l <node>          - Announce local IP addresses"
    $stderr.puts "  p <node>          - Announce public IP address"
    $stderr.puts "  h <node>          - Halt the system (with audio notification)"
    $stderr.puts "  r <node>          - Reboot the system (with audio notification)"
    exit 1
  end
end

# Run main if executed directly
main if __FILE__ == $PROGRAM_NAME
