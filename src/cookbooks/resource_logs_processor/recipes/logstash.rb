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
# DIRECTORIES
#

directory node['logstash']['path']['home'] do
  action :create
  group node['logstash']['service_group']
  mode '0550'
  owner node['logstash']['service_user']
end

directory node['logstash']['path']['bin'] do
  action :create
  group node['logstash']['service_group']
  mode '0550'
  owner node['logstash']['service_user']
end

directory node['logstash']['path']['settings'] do
  action :create
  group node['logstash']['service_group']
  mode '0550'
  owner node['logstash']['service_user']
end

directory node['logstash']['path']['conf'] do
  action :create
  group node['logstash']['service_group']
  mode '0550'
  owner node['logstash']['service_user']
end

directory node['logstash']['path']['plugins'] do
  action :create
  group node['logstash']['service_group']
  mode '0550'
  owner node['logstash']['service_user']
end

directory node['logstash']['path']['data'] do
  action :create
  group node['logstash']['service_group']
  mode '0770'
  owner node['logstash']['service_user']
end

#
# INSTALL LOGSTASH
#

apt_repository 'elastic-apt-repository' do
  action :add
  components %w[main]
  distribution 'stable'
  key 'https://artifacts.elastic.co/GPG-KEY-elasticsearch'
  uri 'https://artifacts.elastic.co/packages/6.x/apt'
end

apt_package 'logstash' do
  action :install
  version node['logstash']['version']
end

logstash_service_name = node['logstash']['service_name']
service logstash_service_name do
  action :disable
end

#
# CONFIGURATION FILES
#

# Note the memory settings for Logstash are set via the service script so that Logstash can be
# given a percentage of the available memory on the machine
file "#{node['logstash']['path']['settings']}/jvm.options" do
  action :create
  content <<~OPTIONS
    ## JVM configuration

    ################################################################
    ## Expert settings
    ################################################################
    ##
    ## All settings below this section are considered
    ## expert settings. Don't tamper with them unless
    ## you understand what you are doing
    ##
    ################################################################

    -server
    -XX:+AlwaysPreTouch

    ## GC configuration
    -XX:+UseConcMarkSweepGC
    -XX:+ExplicitGCInvokesConcurrent
    -XX:+ParallelRefProcEnabled
    -XX:+UseStringDeduplication
    -XX:+CMSParallelRemarkEnabled
    -XX:+CMSIncrementalMode
    -XX:CMSInitiatingOccupancyFraction=75

    # Prefer the IPv4 stack because Java / Jolokia hates IPv6
    -Djava.net.preferIPv4Stack=true

    ## Locale
    # Set the locale language
    #-Duser.language=en

    # Set the locale country
    #-Duser.country=US

    # Set the locale variant, if any
    #-Duser.variant=

    ## basic

    # set the I/O temp directory
    #-Djava.io.tmpdir=$HOME

    # set to headless, just in case
    -Djava.awt.headless=true

    # ensure UTF-8 encoding by default (e.g. filenames)
    -Dfile.encoding=UTF-8

    # use our provided JNA always versus the system one
    #-Djna.nosys=true

    # Turn on JRuby invokedynamic
    -Djruby.compile.invokedynamic=true
    # Force Compilation
    -Djruby.jit.threshold=0

    ## heap dumps

    # generate a heap dump when an allocation from the Java heap fails
    # heap dumps are created in the working directory of the JVM
    -XX:+HeapDumpOnOutOfMemoryError

    # specify an alternative path for heap dumps
    # ensure the directory exists and has sufficient space
    #-XX:HeapDumpPath=${LOGSTASH_HOME}/heapdump.hprof

    ## GC logging
    #-XX:+PrintGCDetails
    #-XX:+PrintGCTimeStamps
    #-XX:+PrintGCDateStamps
    #-XX:+PrintClassHistogram
    #-XX:+PrintTenuringDistribution
    #-XX:+PrintGCApplicationStoppedTime

    # log GC status to a file with time stamps
    # ensure the directory exists
    #-Xloggc:${LS_GC_LOG_FILE}

    # Entropy source for randomness
    -Djava.security.egd=file:/dev/urandom
  OPTIONS
  group node['logstash']['service_group']
  mode '0550'
  owner node['logstash']['service_user']
end

file "#{node['logstash']['path']['settings']}/log4j2.properties" do
  action :create
  content <<~YML
    log4j.rootLogger=INFO, SYSLOG

    log4j.appender.SYSLOG=com.github.loggly.log4j.SyslogAppender64k
    log4j.appender.SYSLOG.SyslogHost=localhost
    log4j.appender.SYSLOG.Facility=Local0
    log4j.appender.SYSLOG.Header=true
    log4j.appender.SYSLOG.layout=org.apache.log4j.EnhancedPatternLayout
    log4j.appender.SYSLOG.layout.ConversionPattern=java %d{ISO8601}{GMT} %p %t %c %M - %m%n
  YML
  group node['logstash']['service_group']
  mode '0550'
  owner node['logstash']['service_user']
end
