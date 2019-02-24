# frozen_string_literal: true

#
# Cookbook Name:: resource_logs_processor
# Recipe:: default
#
# Copyright 2019, P. van der Velde
#

# Always make sure that apt is up to date
apt_update 'update' do
  action :update
end

#
# Include the local recipes
#

include_recipe 'resource_logs_processor::firewall'

include_recipe 'resource_logs_processor::meta'
include_recipe 'resource_logs_processor::provisioning'

include_recipe 'resource_logs_processor::java'
include_recipe 'resource_logs_processor::logstash'
include_recipe 'resource_logs_processor::logstash_service'
include_recipe 'resource_logs_processor::logstash_templates'
include_recipe 'resource_logs_processor::logstash_metrics'
