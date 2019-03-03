# frozen_string_literal: true

#
# Cookbook Name:: resource_logs_processor
# Recipe:: provisioning
#
# Copyright 2019, P. van der Velde
#

service 'provision.service' do
  action [:enable]
end
