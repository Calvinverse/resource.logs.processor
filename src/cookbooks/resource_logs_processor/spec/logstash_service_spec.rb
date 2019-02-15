# frozen_string_literal: true

require 'spec_helper'

describe 'resource_logs_processor::logstash_service' do
  context 'installs logstash as a service' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    logstash_service_script_content = <<~SH
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

      . "$(cd /usr/share/logstash; pwd)/bin/logstash.lib.sh"
      setup

      unset CLASSPATH
      for J in $(cd "${LOGSTASH_JARS}"; ls *.jar); do
        CLASSPATH=${CLASSPATH}${CLASSPATH:+:}${LOGSTASH_JARS}/${J}
      done
      nohup "${JAVACMD}" ${JAVA_OPTS} ${java_max_memory} -cp "${CLASSPATH}" org.logstash.Logstash "$@" <&- &

      echo "$!" >"/tmp/logstash_pid"
    SH
    it 'creates the /usr/share/logstash/run_logstash.sh file' do
      expect(chef_run).to create_file('/usr/share/logstash/run_logstash.sh')
        .with_content(logstash_service_script_content)
        .with(
          group: 'logstash',
          owner: 'logstash',
          mode: '0550'
        )
    end

    it 'updates the logstash service' do
      expect(chef_run).to create_systemd_service('logstash').with(
        action: [:create],
        install_wanted_by: %w[multi-user.target],
        service_exec_start: '/usr/share/logstash/run_logstash.sh',
        service_limit_nofile: 16_384,
        service_nice: 19,
        service_pid_file: '/tmp/logstash_pid',
        service_restart: 'always',
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
end
