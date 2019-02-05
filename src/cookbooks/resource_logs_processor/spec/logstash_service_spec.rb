# frozen_string_literal: true

require 'spec_helper'

describe 'resource_logs_processor::logstash_service' do
  context 'installs logstash as a service' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }
  end

  it 'updates the logstash service' do
    expect(chef_run).to create_systemd_service('logstash').with(
      action: [:create],
      install_wanted_by: %w[multi-user.target],
      service_exec_start: '/usr/local/logstash/run_logstash.sh',
      service_limit_nofile: 16384,
      service_nice: 19,
      service_restart: 'on-failure',
      service_restart_sec: 5,
      service_type: 'forking',
      service_user: 'logstash',
      unit_after: %w[network-online.target],
      unit_description: 'Logstash',
      unit_requires: %w[network-online.target],
      unit_start_limit_interval_sec: 0
    )
  end

  it 'enables the logstash service' do
    expect(chef_run).to enable_service('logstash')
  end
end
