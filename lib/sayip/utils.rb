# frozen_string_literal: true

#
# Core SayIP logic for AllStarLink nodes.
# Copyright (c) 2025-2026 Jory A. Pratt, W5GLE <geekypenguin@gmail.com>
#

require 'ipaddr'
require 'net/http'
require 'socket'
require 'tempfile'
require 'uri'

module SayIP
  class Utils
    LOCAL_AUDIO_FILE = 'ip-address'
    PUBLIC_AUDIO_PATH = 'public-ip-address'
    HALT_AUDIO = 'halt'
    REBOOT_AUDIO = 'reboot'

    IP_URLS = [
      'https://api.ipify.org',
      'https://ifconfig.me'
    ].freeze

    CHAR_SOUND_MAP = {
      '.' => 'letters/dot.ulaw',
      '-' => 'letters/dash.ulaw',
      '=' => 'letters/equals.ulaw',
      '/' => 'letters/slash.ulaw',
      '!' => 'letters/exclaimation-point.ulaw',
      '@' => 'letters/at.ulaw',
      '$' => 'letters/dollar.ulaw'
    }.freeze

    DEFAULT_SKIP_PREFIXES = %w[lo docker veth br-].freeze
    ULAW_BYTES_PER_SEC = 8000.0
    CONFIG_PATH = '/etc/default/sayip'

    DEFAULT_CONFIG = {
      astsnd: '/usr/share/asterisk/sounds/en',
      custom_sounds: '/usr/local/share/asterisk/sounds',
      playback_padding: 0.5,
      sleep_after_intro: 0.0,
      skip_if_prefix: DEFAULT_SKIP_PREFIXES,
      local_ip_mode: 'default_route',
      local_ip_interface: '',
      prefer_interfaces: [],
      user_agent: 'sayip-node-utils/1.0'
    }.freeze

    def self.default
      @default ||= new
    end

    def initialize(overrides = {})
      @config = DEFAULT_CONFIG.merge(load_config_file).merge(overrides)
      @config[:skip_if_prefix] = parse_skip_prefixes(@config[:skip_if_prefix])
      @config[:prefer_interfaces] = parse_interface_list(@config[:prefer_interfaces])
    end

    attr_reader :config

    def validate_node(node)
      return false unless node

      node.match?(/^\d{1,10}$/)
    end

    def parse_ipv4(text)
      addr = IPAddr.new(text.strip)
      return text.strip if addr.ipv4?

      nil
    rescue IPAddr::InvalidAddressError
      nil
    end

    def usable_local_ipv4(text)
      parsed = parse_ipv4(text)
      return nil unless parsed

      addr = IPAddr.new(parsed)
      return nil if addr.loopback?

      parsed
    rescue IPAddr::InvalidAddressError
      nil
    end

    def asterisk_cmd(cmd)
      ok = system('asterisk', '-rx', cmd, out: File::NULL, err: File::NULL)
      warn "Warning: Asterisk command failed: #{cmd}" unless ok
      ok
    end

    def play_audio(node, audio_path)
      unless asterisk_cmd("rpt localplay #{node} #{audio_path}")
        warn "Warning: Failed to play audio #{audio_path} on node #{node}"
        return false
      end
      true
    end

    def get_local_ips
      select_configured_local_ips.uniq
    rescue StandardError => e
      warn "Warning: Error getting local IPs: #{e.message}"
      []
    end

    def get_public_ip
      IP_URLS.each do |url|
        ip = fetch_ip_from(url)
        return ip if ip
      end
      nil
    end

    def say_local_ip(node, program_name: $PROGRAM_NAME)
      unless validate_node(node)
        $stderr.puts "No valid node number supplied - usage: #{program_name} local <node>"
        exit 1
      end

      warn 'Warning: Intro audio failed; continuing with IP announcement' unless play_audio(node, LOCAL_AUDIO_FILE)
      wait_for_playback(LOCAL_AUDIO_FILE)

      ips = get_local_ips
      if ips.empty?
        warn 'Warning: No local IP addresses found'
        return
      end

      ips.each do |ip|
        speak_text(ip, node)
      end
    end

    def say_public_ip(node, program_name: $PROGRAM_NAME)
      unless validate_node(node)
        $stderr.puts "Usage: #{program_name} public <node_number>"
        exit 1
      end

      ip = get_public_ip
      unless ip
        $stderr.puts 'Failed to retrieve a valid public IP address from all sources'
        exit 1
      end

      unless play_audio(node, PUBLIC_AUDIO_PATH)
        $stderr.puts 'Failed to play public IP intro audio'
        exit 1
      end
      wait_for_playback(PUBLIC_AUDIO_PATH)
      speak_text(ip, node)
    end

    def halt_system(node, force: false, program_name: $PROGRAM_NAME)
      unless validate_node(node) || force
        $stderr.puts "Usage: #{program_name} halt <node>  (or #{program_name} halt --force)"
        exit 1
      end

      if validate_node(node)
        play_audio(node, HALT_AUDIO)
        wait_for_playback(HALT_AUDIO)
      end

      run_shutdown(:halt)
    end

    def reboot_system(node, force: false, program_name: $PROGRAM_NAME)
      unless validate_node(node) || force
        $stderr.puts "Usage: #{program_name} reboot <node>  (or #{program_name} reboot --force)"
        exit 1
      end

      if validate_node(node)
        play_audio(node, REBOOT_AUDIO)
        wait_for_playback(REBOOT_AUDIO)
      end

      run_shutdown(:reboot)
    end

    private

    def load_config_file
      return {} unless File.readable?(CONFIG_PATH)

      config = {}
      File.readlines(CONFIG_PATH, chomp: true).each do |line|
        line = line.strip
        next if line.empty? || line.start_with?('#')

        key, value = line.split('=', 2)
        next unless key && value

        apply_config_setting(config, key.strip, value.strip)
      end
      config
    rescue StandardError => e
      warn "Warning: Could not read #{CONFIG_PATH}: #{e.message}"
      {}
    end

    def apply_config_setting(config, key, value)
      case key
      when 'ASTSND'
        config[:astsnd] = value
      when 'CUSTOM_SOUNDS'
        config[:custom_sounds] = value
      when 'PLAYBACK_PADDING'
        config[:playback_padding] = value.to_f
      when 'SLEEP_AFTER_INTRO'
        config[:sleep_after_intro] = value.to_f
      when 'SKIP_IF_PREFIX'
        config[:skip_if_prefix] = value
      when 'LOCAL_IP_MODE'
        config[:local_ip_mode] = value.downcase
      when 'LOCAL_IP_INTERFACE'
        config[:local_ip_interface] = value
      when 'PREFER_INTERFACES'
        config[:prefer_interfaces] = value
      when 'PREFER_DEFAULT_ROUTE'
        # Legacy setting: "no" meant announce all interfaces in older releases.
        config[:local_ip_mode] = 'all' unless %w[yes true 1].include?(value.downcase)
      when 'USER_AGENT'
        config[:user_agent] = value
      end
    end

    def parse_skip_prefixes(value)
      case value
      when Array
        value
      when String
        value.split(',').map(&:strip).reject(&:empty?)
      else
        DEFAULT_SKIP_PREFIXES.dup
      end
    end

    def skipped_interface?(name)
      @config[:skip_if_prefix].any? { |prefix| name.start_with?(prefix) }
    end

    def parse_interface_list(value)
      case value
      when Array
        value.map(&:to_s).map(&:strip).reject(&:empty?)
      when String
        value.split(',').map(&:strip).reject(&:empty?)
      else
        []
      end
    end

    def local_ip_mode
      mode = @config[:local_ip_mode].to_s.downcase
      mode == 'all' ? 'all' : 'default_route'
    end

    def select_configured_local_ips
      iface = @config[:local_ip_interface].to_s.strip
      return ip_on_named_interface(iface) unless iface.empty?

      @config[:prefer_interfaces].each do |preferred|
        ip = ip_on_interface(preferred)
        return [ip] if ip
      end

      case local_ip_mode
      when 'all'
        select_all_local_ips
      else
        select_default_route_ip
      end
    end

    def ip_on_named_interface(iface)
      ip = ip_on_interface(iface)
      unless ip
        warn "Warning: No IPv4 address on configured interface #{iface}"
        return []
      end

      [ip]
    end

    def select_default_route_ip
      iface = default_route_iface
      unless iface
        warn 'Warning: No default IPv4 route found; falling back to primary interface'
        return select_all_local_ips.take(1)
      end

      ip = ip_on_interface(iface)
      unless ip
        warn "Warning: No IPv4 address on default-route interface #{iface}; falling back to primary interface"
        return select_all_local_ips.take(1)
      end

      [ip]
    end

    def select_all_local_ips
      pairs = collect_ips_from_ifaddrs
      pairs = collect_ips_from_ip_addr if pairs.empty?
      pairs.map(&:first)
    end

    def ip_on_interface(iface)
      pairs = collect_ips_from_ifaddrs(skip_filtered: false)
      pairs = collect_ips_from_ip_addr(skip_filtered: false) if pairs.empty?

      match = pairs.find { |(_, name)| name == iface }
      match&.first
    end

    def default_route_iface
      IO.popen(%w[ip -4 route show default], err: File::NULL) do |io|
        io.each_line do |line|
          return Regexp.last_match(1) if line =~ /\bdev\s+(\S+)/
        end
      end
      nil
    rescue StandardError
      nil
    end

    def collect_ips_from_ifaddrs(skip_filtered: true)
      return [] unless Socket.respond_to?(:getifaddrs)

      pairs = []
      Socket.getifaddrs.each do |ifaddr|
        next if skip_filtered && skipped_interface?(ifaddr.name)
        next unless ifaddr.addr&.ipv4?

        ip = ifaddr.addr.ip_address
        parsed = usable_local_ipv4(ip)
        pairs << [parsed, ifaddr.name] if parsed
      end
      pairs
    end

    def collect_ips_from_ip_addr(skip_filtered: true)
      pairs = []
      current_iface = nil

      IO.popen(%w[ip addr show], err: File::NULL) do |io|
        io.each_line do |line|
          if line =~ /^\d+:\s+([^:@]+)/
            current_iface = Regexp.last_match(1)
          elsif line =~ %r{inet\s+(\d{1,3}(?:\.\d{1,3}){3})/}
            ip = Regexp.last_match(1)
            next if current_iface.nil? || (skip_filtered && skipped_interface?(current_iface))

            parsed = usable_local_ipv4(ip)
            pairs << [parsed, current_iface] if parsed
          end
        end
      end

      pairs
    end

    def fetch_ip_from(url)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.read_timeout = 10
      http.open_timeout = 5

      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = @config[:user_agent]

      response = http.request(request)
      return nil unless response.is_a?(Net::HTTPSuccess)

      parse_ipv4(response.body)
    rescue StandardError => e
      warn "IP service #{url} failed: #{e.message}"
      nil
    end

    def resolve_ulaw_path(basename)
      base = basename.sub(/\.ulaw\z/, '')
      if base.include?('/')
        path = "#{base}.ulaw"
        return path if File.exist?(path)
      else
        [@config[:custom_sounds], @config[:astsnd]].each do |dir|
          path = File.join(dir, "#{base}.ulaw")
          return path if File.exist?(path)
        end
      end
      nil
    end

    def ulaw_duration(path)
      size = File.size?(path) || 0
      (size / ULAW_BYTES_PER_SEC) + @config[:playback_padding]
    end

    def wait_for_playback(audio_path)
      ulaw = resolve_ulaw_path(audio_path)
      duration = if ulaw
                   ulaw_duration(ulaw)
                 elsif @config[:sleep_after_intro].positive?
                   @config[:sleep_after_intro]
                 else
                   5.0
                 end
      sleep(duration)
    end

    def add_sound(output_file, sound_file)
      full_path = File.join(@config[:astsnd], sound_file)

      unless File.exist?(full_path)
        warn "Warning: Sound file #{full_path} not found, skipping..."
        return
      end

      File.open(full_path, 'rb') do |sound_fh|
        output_file.write(sound_fh.read)
      end
    end

    def speak_text(text, node)
      speaktext = text.downcase

      Tempfile.create(['localmsg', '.ulaw'], '/tmp') do |tmp|
        tmp.binmode
        speaktext.each_char do |ch|
          sound_file = char_to_sound(ch)
          if sound_file
            add_sound(tmp, sound_file)
          else
            warn "Unsupported character: #{ch}"
          end
        end
        tmp.flush
        tmp.fsync
        tmp.chmod(0o644)

        play_path = tmp.path.sub(/\.ulaw\z/, '')
        play_audio(node, play_path)
        sleep(ulaw_duration(tmp.path))
      end
    end

    def char_to_sound(ch)
      case ch
      when /[A-Za-z_]/
        "letters/#{ch}.ulaw"
      when /[0-9]/
        "digits/#{ch}.ulaw"
      else
        CHAR_SOUND_MAP[ch]
      end
    end

    def run_shutdown(kind)
      cmd = kind == :halt ? '/usr/sbin/poweroff' : '/usr/sbin/reboot'

      if Process.euid.zero?
        exec(cmd)
      else
        exec('sudo', '-n', cmd)
      end

      # exec only returns on failure
      $stderr.puts "Failed to run #{cmd} (are you root or configured in sudoers?)"
      exit 1
    end
  end
end
