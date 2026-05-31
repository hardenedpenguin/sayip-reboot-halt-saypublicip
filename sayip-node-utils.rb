#!/usr/bin/env ruby
# frozen_string_literal: true

#
# sayip-node-utils - Unified Ruby script for SayIP functionality
# Handles local IP, public IP, halt, and reboot
# Copyright (c) 2025-2026 Jory A. Pratt, W5GLE <geekypenguin@gmail.com>
#

utils_path = if File.exist?(File.expand_path('lib/sayip/utils.rb', __dir__))
               File.expand_path('lib/sayip/utils.rb', __dir__)
             else
               '/usr/lib/sayip-node-utils/utils.rb'
             end
require utils_path

def parse_force_flag!
  force = false
  while (arg = ARGV.first) && arg.start_with?('-')
    force = true if arg == '--force'
    ARGV.shift
  end
  force
end

def print_usage(program_name)
  $stderr.puts "Usage: #{program_name} <action> [arguments]"
  $stderr.puts ''
  $stderr.puts 'Actions (long form):'
  $stderr.puts '  local <node>           - Announce local IP addresses'
  $stderr.puts '  public <node>          - Announce public IP address'
  $stderr.puts '  halt <node> [--force]  - Halt the system (with audio notification)'
  $stderr.puts '  reboot <node> [--force]- Reboot the system (with audio notification)'
  $stderr.puts ''
  $stderr.puts 'Actions (short form):'
  $stderr.puts '  l <node>               - Announce local IP addresses'
  $stderr.puts '  p <node>               - Announce public IP address'
  $stderr.puts '  h <node> [--force]     - Halt the system (with audio notification)'
  $stderr.puts '  r <node> [--force]     - Reboot the system (with audio notification)'
  $stderr.puts ''
  $stderr.puts 'Use --force to halt/reboot without a valid node number (no audio).'
end

def main
  program_name = File.basename($PROGRAM_NAME)
  utils = SayIP::Utils.default
  action = ARGV.shift

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
    utils.say_local_ip(node, program_name: program_name)
  when 'public'
    node = ARGV.shift
    utils.say_public_ip(node, program_name: program_name)
  when 'halt'
    force = parse_force_flag!
    node = ARGV.shift
    utils.halt_system(node, force: force, program_name: program_name)
  when 'reboot'
    force = parse_force_flag!
    node = ARGV.shift
    utils.reboot_system(node, force: force, program_name: program_name)
  else
    print_usage(program_name)
    exit 1
  end
end

main if __FILE__ == $PROGRAM_NAME
