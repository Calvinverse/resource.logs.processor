# frozen_string_literal: true

require 'spec_helper'

describe 'resource_logs_processor::logstash' do
  context 'installs logstash' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

  end
end