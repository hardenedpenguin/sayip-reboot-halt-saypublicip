# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/sayip/utils'

class SayIPBusyTest < Minitest::Test
  def setup
    @utils = SayIP::Utils.new(
      skip_if_prefix: %w[docker veth br-],
      local_ip_mode: 'all',
      playback_padding: 0.0
    )
  end

  def test_xnode_busy_when_rx_keyed
    output = "RPT_RXKEYED=1\nRPT_TXKEYED=0\n"
    assert @utils.send(:xnode_busy?, output)
  end

  def test_xnode_not_busy_when_all_clear
    output = "RPT_RXKEYED=0\nRPT_TXKEYED=0\nRPT_ETXKEYED=0\n"
    refute @utils.send(:xnode_busy?, output)
  end

  def test_stats_busy_when_identifier_queued
    output = "Identifier state.................................: QUEUED IN TAIL\n"
    assert @utils.send(:stats_busy?, output)
  end

  def test_stats_not_busy_when_identifier_clean
    output = "Identifier state.................................: CLEAN\n"
    refute @utils.send(:stats_busy?, output)
  end

  def test_ensure_channel_idle_skips_immediately_when_busy_and_no_wait
    utils = SayIP::Utils.new(busy_check: true, busy_wait_max: 0.0, busy_poll_interval: 0.1)

    utils.stub(:node_channel_busy?, true) do
      refute utils.ensure_channel_idle('546052')
    end
  end

  def test_ensure_channel_idle_waits_until_clear
    utils = SayIP::Utils.new(busy_check: true, busy_wait_max: 2.0, busy_poll_interval: 0.05)
    checks = 0

    busy_proc = proc do
      checks += 1
      checks < 3
    end

    utils.stub(:node_channel_busy?, busy_proc) do
      assert utils.ensure_channel_idle('546052')
    end

    assert checks >= 3
  end

  def test_ensure_channel_idle_disabled_always_allows_playback
    utils = SayIP::Utils.new(busy_check: false)

    utils.stub(:node_channel_busy?, true) do
      assert utils.ensure_channel_idle('546052')
    end
  end
end
