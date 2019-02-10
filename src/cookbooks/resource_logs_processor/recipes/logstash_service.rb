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

run_logstash_script = "#{node['logstash']['path']['home']}/run_logstash.sh"
logstash_pid_file = "#{node['logstash']['path']['home']}/logstash_pid"
file run_logstash_script do
  action :create
  content <<~SH
    #!/bin/bash
    # Run logstash from source
    #
    # This is most useful when done from a git checkout.
    #
    # Usage:
    #   bin/logstash <command> [arguments]
    #
    # See 'bin/logstash --help' for a list of commands.
    #
    # Supported environment variables:
    #   LS_JAVA_OPTS="xxx" to append extra options to the JVM options provided by logstash
    #
    # Development environment variables:
    #   DEBUG=1 to output debugging information

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

    . "$(cd #{node['logstash']['path']['home']}; pwd)/bin/logstash.lib.sh"
    setup

    unset CLASSPATH
    for J in $(cd "${LOGSTASH_JARS}"; ls *.jar); do
      CLASSPATH=${CLASSPATH}${CLASSPATH:+:}${LOGSTASH_JARS}/${J}
    done
    nohub "${JAVACMD}" ${JAVA_OPTS} ${java_max_memory} -cp "${CLASSPATH}" org.logstash.Logstash "$@" <&- &

    echo "$!" >"#{logstash_pid_file}"
  SH
  group node['logstash']['service_group']
  mode '0550'
  owner node['logstash']['service_user']
end

logstash_user = node['logstash']['service_user']
logstash_service_name = node['logstash']['service_name']
systemd_service logstash_service_name do
  action :create
  install do
    wanted_by %w[multi-user.target]
  end
  service do
    # Load env vars from /etc/default/ and /etc/sysconfig/ if they exist.
    # Prefixing the path with '-' makes it try to load, but if the file doesn't
    # exist, it continues onward.
    environment_file '-/etc/default/logstash'
    environment_file '-/etc/sysconfig/logstash'
    exec_start run_logstash_script
    limit_nofile 16_384
    nice 19
    pid_file logstash_pid_file
    restart 'always'
    restart_sec 5
    type 'forking'
    user logstash_user
  end
  unit do
    after %w[network-online.target]
    description 'Logstash'
    documentation 'https://elastic.co'
    requires %w[network-online.target]
    start_limit_interval_sec 0
  end
end

service logstash_service_name do
  action :enable
end
