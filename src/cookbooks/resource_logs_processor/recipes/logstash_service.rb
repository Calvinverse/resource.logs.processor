# frozen_string_literal: true

#
# Cookbook Name:: resource_logs_processor
# Recipe:: logstash_service
#
# Copyright 2019, P. van der Velde
#

#
# INSTALL THE CALCULATOR
#

apt_package 'bc' do
  action :install
end

#
# SYSTEMD SERVICE
#

# From here: https://logstash.io/blog/2016/11/21/gc-tuning/
java_server_args = '-server -XX:+AlwaysPreTouch'
java_gc_args =
  '-XX:+UseConcMarkSweepGC' \
  ' -XX:+ExplicitGCInvokesConcurrent' \
  ' -XX:+ParallelRefProcEnabled' \
  ' -XX:+UseStringDeduplication' \
  ' -XX:+CMSParallelRemarkEnabled' \
  ' -XX:+CMSIncrementalMode' \
  ' -XX:CMSInitiatingOccupancyFraction=75'

java_awt_args = '-Djava.awt.headless=true'

# Make sure java prefers IPv4 over IPv6 because Jolokia doesn't like IPv6
java_ipv4_args = '-Djava.net.preferIPv4Stack=true'

# Settings (from here: https://wiki.logstash-ci.org/display/logstash/Features+controlled+by+system+properties)
logstash_java_args = ''

# Turn on GC logging
java_diagnostics =
  '-Xloggc:/var/log/logstash_gc-%t.log' \
  ' -XX:NumberOfGCLogFiles=10' \
  ' -XX:+UseGCLogFileRotation' \
  ' -XX:GCLogFileSize=25m' \
  ' -XX:+PrintGC' \
  ' -XX:+PrintGCDateStamps' \
  ' -XX:+PrintGCDetails' \
  ' -XX:+PrintHeapAtGC' \
  ' -XX:+PrintGCCause' \
  ' -XX:+PrintTenuringDistribution' \
  ' -XX:+PrintReferenceGC' \
  ' -XX:+PrintAdaptiveSizePolicy' \
  ' -XX:+HeapDumpOnOutOfMemoryError'

logstash_user = node['logstash']['service_user']
logstash_war_path = node['logstash']['path']['war_file']
logstash_pid_file = node['logstash']['path']['pid_file']

run_logstash_script = '/usr/local/logstash/run_logstash.sh'
file run_logstash_script do
  action :create
  content <<~SH
    #!/bin/sh

    #
    # Original from here: https://github.com/fabric8io-images/java/blob/master/images/jboss/openjdk8/jdk/run-java.sh
    # Licensed with the Apache 2.0 license as of 2017-10-22
    #

    # ==========================================================
    # Generic run script for running arbitrary Java applications
    #
    # Source and Documentation can be found
    # at https://github.com/fabric8io/run-java-sh
    #
    # ==========================================================

    max_memory() {
      max_mem=$(free -m | grep -oP '\\d+' | head -n 1)
      echo "${max_mem}"
    }

    # Start JVM
    startup() {
      echo "Determining max memory usage ..."
      java_max_memory=""

      # Check for the 'real memory size' and calculate mx from a ratio
      # given (default is 70%)
      max_mem="$(max_memory)"
      if [ "x${max_mem}" != "x0" ]; then
        ratio=70

        mx=$(echo "(${max_mem} * ${ratio} / 100 + 0.5)" | bc | awk '{printf("%d\\n",$1 + 0.5)}')
        java_max_memory="-Xmx${mx}m -Xms${mx}m"

        echo "Maximum memory for VM set to ${max_mem}. Setting max memory for java to ${mx} Mb"
      fi

      user_java_opts="#{java_server_args} #{java_gc_args} #{java_awt_args} #{java_ipv4_args} #{logstash_java_args}"
      user_java_jar_opts="#{logstash_args}"

      echo nohup java ${user_java_opts} ${java_max_memory} #{java_diagnostics} #{logstash_metrics_args} -jar #{logstash_war_path} ${user_java_jar_opts}
      nohup java ${user_java_opts} ${java_max_memory} #{java_diagnostics} #{logstash_metrics_args} -jar #{logstash_war_path} ${user_java_jar_opts} 2>&1 &
      echo "$!" >"#{logstash_pid_file}"
    }

    # =============================================================================
    # Fire up
    startup
  SH
  group node['logstash']['service_group']
  mode '0550'
  owner node['logstash']['service_user']
end

logstash_service_name = node['logstash']['service_name']
logstash_environment_file = node['logstash']['path']['environment_file']
systemd_service logstash_service_name do
  action :create
  install do
    wanted_by %w[multi-user.target]
  end
  service do
    environment_file logstash_environment_file
    exec_reload "/usr/bin/curl http://localhost:#{logstash_http_port}/#{proxy_path}/reload"
    exec_start run_logstash_script
    exec_stop "/usr/bin/curl http://localhost:#{logstash_http_port}/#{proxy_path}/safeExit"
    pid_file logstash_pid_file
    restart 'on-failure'
    type 'forking'
    user logstash_user
  end
  unit do
    after %w[network-online.target]
    description 'logstash CI system'
    documentation 'https://logstash.io'
    requires %w[network-online.target]
  end
end

service logstash_service_name do
  action :disable
end
