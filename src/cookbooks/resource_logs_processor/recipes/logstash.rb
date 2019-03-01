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
    appender.syslog.name = syslog
    appender.syslog.type = Syslog
    appender.syslog.host = localhost
    appender.syslog.protocol = tcp
    appender.syslog.port = 514

    appender.console.type = Console
    appender.console.name = plain_console
    appender.console.layout.type = PatternLayout
    appender.console.layout.pattern = [%d{ISO8601}][%-5p][%-25c] %m%n

    appender.json_console.type = Console
    appender.json_console.name = json_console
    appender.json_console.layout.type = JSONLayout
    appender.json_console.layout.compact = true
    appender.json_console.layout.eventEol = true

    appender.rolling.type = RollingFile
    appender.rolling.name = plain_rolling
    appender.rolling.fileName = ${sys:ls.logs}/logstash-${sys:ls.log.format}.log
    appender.rolling.filePattern = ${sys:ls.logs}/logstash-${sys:ls.log.format}-%d{yyyy-MM-dd}-%i.log.gz
    appender.rolling.policies.type = Policies
    appender.rolling.policies.time.type = TimeBasedTriggeringPolicy
    appender.rolling.policies.time.interval = 1
    appender.rolling.policies.time.modulate = true
    appender.rolling.layout.type = PatternLayout
    appender.rolling.layout.pattern = [%d{ISO8601}][%-5p][%-25c] %-.10000m%n
    appender.rolling.policies.size.type = SizeBasedTriggeringPolicy
    appender.rolling.policies.size.size = 100MB

    appender.json_rolling.type = RollingFile
    appender.json_rolling.name = json_rolling
    appender.json_rolling.fileName = ${sys:ls.logs}/logstash-${sys:ls.log.format}.log
    appender.json_rolling.filePattern = ${sys:ls.logs}/logstash-${sys:ls.log.format}-%d{yyyy-MM-dd}-%i.log.gz
    appender.json_rolling.policies.type = Policies
    appender.json_rolling.policies.time.type = TimeBasedTriggeringPolicy
    appender.json_rolling.policies.time.interval = 1
    appender.json_rolling.policies.time.modulate = true
    appender.json_rolling.layout.type = JSONLayout
    appender.json_rolling.layout.compact = true
    appender.json_rolling.layout.eventEol = true
    appender.json_rolling.policies.size.type = SizeBasedTriggeringPolicy
    appender.json_rolling.policies.size.size = 100MB


    rootLogger.level = ${sys:ls.log.level}
    rootLogger.appenderRef.syslog.ref = syslog
    rootLogger.appenderRef.console.ref = ${sys:ls.log.format}_console
    rootLogger.appenderRef.rolling.ref = ${sys:ls.log.format}_rolling

    # Slowlog

    appender.console_slowlog.type = Console
    appender.console_slowlog.name = plain_console_slowlog
    appender.console_slowlog.layout.type = PatternLayout
    appender.console_slowlog.layout.pattern = [%d{ISO8601}][%-5p][%-25c] %m%n

    appender.json_console_slowlog.type = Console
    appender.json_console_slowlog.name = json_console_slowlog
    appender.json_console_slowlog.layout.type = JSONLayout
    appender.json_console_slowlog.layout.compact = true
    appender.json_console_slowlog.layout.eventEol = true

    appender.rolling_slowlog.type = RollingFile
    appender.rolling_slowlog.name = plain_rolling_slowlog
    appender.rolling_slowlog.fileName = ${sys:ls.logs}/logstash-slowlog-${sys:ls.log.format}.log
    appender.rolling_slowlog.filePattern = ${sys:ls.logs}/logstash-slowlog-${sys:ls.log.format}-%d{yyyy-MM-dd}-%i.log.gz
    appender.rolling_slowlog.policies.type = Policies
    appender.rolling_slowlog.policies.time.type = TimeBasedTriggeringPolicy
    appender.rolling_slowlog.policies.time.interval = 1
    appender.rolling_slowlog.policies.time.modulate = true
    appender.rolling_slowlog.layout.type = PatternLayout
    appender.rolling_slowlog.layout.pattern = [%d{ISO8601}][%-5p][%-25c] %.10000m%n
    appender.rolling_slowlog.policies.size.type = SizeBasedTriggeringPolicy
    appender.rolling_slowlog.policies.size.size = 100MB

    appender.json_rolling_slowlog.type = RollingFile
    appender.json_rolling_slowlog.name = json_rolling_slowlog
    appender.json_rolling_slowlog.fileName = ${sys:ls.logs}/logstash-slowlog-${sys:ls.log.format}.log
    appender.json_rolling_slowlog.filePattern = ${sys:ls.logs}/logstash-slowlog-${sys:ls.log.format}-%d{yyyy-MM-dd}-%i.log.gz
    appender.json_rolling_slowlog.policies.type = Policies
    appender.json_rolling_slowlog.policies.time.type = TimeBasedTriggeringPolicy
    appender.json_rolling_slowlog.policies.time.interval = 1
    appender.json_rolling_slowlog.policies.time.modulate = true
    appender.json_rolling_slowlog.layout.type = JSONLayout
    appender.json_rolling_slowlog.layout.compact = true
    appender.json_rolling_slowlog.layout.eventEol = true
    appender.json_rolling_slowlog.policies.size.type = SizeBasedTriggeringPolicy
    appender.json_rolling_slowlog.policies.size.size = 100MB

    logger.slowlog.name = slowlog
    logger.slowlog.level = trace
    logger.slowlog.appenderRef.console_slowlog.ref = ${sys:ls.log.format}_console_slowlog
    logger.slowlog.appenderRef.rolling_slowlog.ref = ${sys:ls.log.format}_rolling_slowlog
    logger.slowlog.additivity = false
  YML
  group node['logstash']['service_group']
  mode '0550'
  owner node['logstash']['service_user']
end
