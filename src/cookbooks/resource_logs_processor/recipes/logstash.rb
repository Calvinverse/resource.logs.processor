# frozen_string_literal: true

#
# Cookbook Name:: resource_logs_processor
# Recipe:: logstash
#
# Copyright 2019, P. van der Velde
#

# Configure the service user under which consul will be run
poise_service_user node['logstash']['service_user'] do
  group node['logstash']['service_group']
end


#
# INSTALL LOGSTASH
#

apt_repository 'elastic-apt-repository' do
  action :add
  distribution './'
  key 'https://artifacts.elastic.co/GPG-KEY-elasticsearch'
  uri 'https://artifacts.elastic.co/packages/6.x/apt'
end

apt_package 'logstash' do
  action :install
  version node['logstash']['version']
end

service_name = 'logstash'
service service_name do
  action :disable
end
