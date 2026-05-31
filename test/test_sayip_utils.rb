# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/sayip/utils'

class SayIPUtilsTest < Minitest::Test
  def setup
    @utils = SayIP::Utils.new(
      skip_if_prefix: %w[docker veth br-],
      local_ip_mode: 'all',
      playback_padding: 0.0
    )
  end

  def test_validate_node_accepts_valid_numbers
    assert @utils.validate_node('1')
    assert @utils.validate_node('12345')
    assert @utils.validate_node('1234567890')
  end

  def test_validate_node_rejects_invalid_numbers
    refute @utils.validate_node(nil)
    refute @utils.validate_node('')
    refute @utils.validate_node('12345678901')
    refute @utils.validate_node('12ab')
    refute @utils.validate_node('-1')
  end

  def test_parse_ipv4_accepts_valid_ipv4
    assert_equal '192.168.0.10', @utils.parse_ipv4('192.168.0.10')
    assert_equal '10.0.0.1', @utils.parse_ipv4(" 10.0.0.1 \n")
  end

  def test_parse_ipv4_rejects_invalid_or_non_ipv4
    assert_nil @utils.parse_ipv4('999.999.999.999')
    assert_nil @utils.parse_ipv4('not-an-ip')
    assert_nil @utils.parse_ipv4('::1')
  end

  def test_usable_local_ipv4_rejects_loopback
    assert_nil @utils.usable_local_ipv4('127.0.0.1')
    assert_equal '10.8.0.9', @utils.usable_local_ipv4('10.8.0.9')
  end

  def test_get_local_ips_default_route_mode_announces_only_route_interface
    utils = SayIP::Utils.new(local_ip_mode: 'default_route')

    utils.stub(:default_route_iface, 'wrinkles') do
      utils.stub(:collect_ips_from_ifaddrs, lambda { |**_kwargs|
        [['10.8.0.9', 'wrinkles'], ['192.168.1.50', 'wlan0']]
      }) do
        assert_equal ['10.8.0.9'], utils.get_local_ips
      end
    end
  end

  def test_get_local_ips_prefer_interfaces_before_default_route
    utils = SayIP::Utils.new(
      local_ip_mode: 'default_route',
      prefer_interfaces: ['wrinkles']
    )

    utils.stub(:default_route_iface, 'wlan0') do
      utils.stub(:collect_ips_from_ifaddrs, lambda { |**_kwargs|
        [['10.8.0.9', 'wrinkles'], ['10.10.2.50', 'wlan0']]
      }) do
        assert_equal ['10.8.0.9'], utils.get_local_ips
      end
    end
  end

  def test_get_local_ips_local_ip_interface_overrides_default_route
    utils = SayIP::Utils.new(local_ip_interface: 'wrinkles')

    utils.stub(:collect_ips_from_ifaddrs, lambda { |**_kwargs|
      [['10.8.0.9', 'wrinkles'], ['10.10.2.50', 'wlan0']]
    }) do
      assert_equal ['10.8.0.9'], utils.get_local_ips
    end
  end

  def test_get_local_ips_all_mode_announces_every_usable_address
    utils = SayIP::Utils.new(local_ip_mode: 'all')

    utils.stub(:collect_ips_from_ifaddrs, lambda { |**_kwargs|
      [['10.8.0.9', 'wrinkles'], ['192.168.1.50', 'wlan0']]
    }) do
      assert_equal ['10.8.0.9', '192.168.1.50'], utils.get_local_ips
    end
  end

  def test_skipped_interface_matches_prefixes
    assert @utils.send(:skipped_interface?, 'docker0')
    assert @utils.send(:skipped_interface?, 'veth123')
    refute @utils.send(:skipped_interface?, 'eth0')
    refute @utils.send(:skipped_interface?, 'wrinkles')
  end

  def test_ulaw_duration_from_file_size
    Tempfile.create(['test', '.ulaw']) do |tmp|
      tmp.binmode
      tmp.write("\0" * 8000)
      tmp.flush
      assert_in_delta 1.0, @utils.send(:ulaw_duration, tmp.path), 0.01
    end
  end

  def test_char_to_sound_maps_digits_and_symbols
    assert_equal 'digits/3.ulaw', @utils.send(:char_to_sound, '3')
    assert_equal 'letters/dot.ulaw', @utils.send(:char_to_sound, '.')
    assert_nil @utils.send(:char_to_sound, '#')
  end

  def test_config_overrides_merge
    utils = SayIP::Utils.new(user_agent: 'test-agent/1.0', astsnd: '/tmp/sounds')
    assert_equal 'test-agent/1.0', utils.config[:user_agent]
    assert_equal '/tmp/sounds', utils.config[:astsnd]
  end
end
