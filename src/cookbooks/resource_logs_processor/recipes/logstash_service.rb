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

logstash_pid_file = '/tmp/logstash_pid'
run_logstash_script = "#{node['logstash']['path']['home']}/run_logstash.sh"
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
    nohup "${JAVACMD}" ${JAVA_OPTS} ${java_max_memory} -cp "${CLASSPATH}" org.logstash.Logstash "$@" <&- &

    echo "$!" >"#{logstash_pid_file}"
  SH
  group node['logstash']['service_group']
  mode '0550'
  owner node['logstash']['service_user']
end

logstash_lib_script = "#{node['logstash']['path']['bin']}/logstash.lib.sh"
file logstash_lib_script do
  action :create
  content <<~SH
    # This script is used to initialize a number of env variables and setup the
    # runtime environment of logstash. It sets to following env variables:
    #   LOGSTASH_HOME & LS_HOME
    #   SINCEDB_DIR
    #   JAVACMD
    #   JAVA_OPTS
    #   GEM_HOME & GEM_PATH
    #   DEBUG
    #
    # These functions are provided for the calling script:
    #   setup() to setup the environment
    #   ruby_exec() to execute a ruby script with using the setup runtime environment
    #
    # The following env var will be used by this script if set:
    #   LS_GEM_HOME and LS_GEM_PATH to overwrite the path assigned to GEM_HOME and GEM_PATH
    #   LS_JAVA_OPTS to append extra options to the JVM options provided by logstash
    #   JAVA_HOME to point to the java home

    unset CDPATH

    # The logstash start script doesn't really get called in a sensible way (systemd starts it)
    # so the normal Logstash-find-where-we-are approach fails pretty miserably. So we do this the
    # easy way
    SOURCEPATH="/usr/share/logstash/bin/logstash.lib.sh"

    LOGSTASH_HOME="$(cd `dirname $SOURCEPATH`/..; pwd)"
    export LOGSTASH_HOME
    export LS_HOME="${LOGSTASH_HOME}"
    SINCEDB_DIR="${LOGSTASH_HOME}"
    export SINCEDB_DIR
    LOGSTASH_JARS=${LOGSTASH_HOME}/logstash-core/lib/jars

    # iterate over the command line args and look for the argument
    # after --path.settings to see if the jvm.options file is in
    # that path and set LS_JVM_OPTS accordingly
    # This fix is for #6379
    unset LS_JVM_OPTS
    found=0
    for i in "$@"; do
    if [ $found -eq 1 ]; then
      if [ -r "${i}/jvm.options" ]; then
        export LS_JVM_OPTS="${i}/jvm.options"
        break
      fi
    fi
    if [ "$i" = "--path.settings" ]; then
      found=1
    fi
    done

    parse_jvm_options() {
      if [ -f "$1" ]; then
        echo "$(grep "^-" "$1" | tr '\n' ' ')"
      fi
    }

    setup_java() {
      # set the path to java into JAVACMD which will be picked up by JRuby to launch itself
      if [ -x "$JAVA_HOME/bin/java" ]; then
        JAVACMD="$JAVA_HOME/bin/java"
      else
        set +e
        JAVACMD=`command -v java`
        set -e
      fi

      if [ ! -x "$JAVACMD" ]; then
        echo "could not find java; set JAVA_HOME or ensure java is in PATH"
        exit 1
      fi

      # do not let JAVA_TOOL_OPTIONS slip in (as the JVM does by default)
      if [ ! -z "$JAVA_TOOL_OPTIONS" ]; then
        echo "warning: ignoring JAVA_TOOL_OPTIONS=$JAVA_TOOL_OPTIONS"
        unset JAVA_TOOL_OPTIONS
      fi

      # JAVA_OPTS is not a built-in JVM mechanism but some people think it is so we
      # warn them that we are not observing the value of $JAVA_OPTS
      if [ ! -z "$JAVA_OPTS" ]; then
        echo -n "warning: ignoring JAVA_OPTS=$JAVA_OPTS; "
        echo "pass JVM parameters via LS_JAVA_OPTS"
      fi

      # Set a default GC log file for use by jvm.options _before_ it's called.
      if [ -z "$LS_GC_LOG_FILE" ] ; then
        LS_GC_LOG_FILE="./logstash-gc.log"
        fi

        # Set the initial JVM options from the jvm.options file.  Look in
        # /etc/logstash first, and break if that file is found readable there.
        if [ -z "$LS_JVM_OPTS" ]; then
            for jvm_options in /etc/logstash/jvm.options \
                              "$LOGSTASH_HOME"/config/jvm.options;
                               do
                if [ -r "$jvm_options" ]; then
                    LS_JVM_OPTS=$jvm_options
                    break
                fi
            done
        fi
        # then override with anything provided
        LS_JAVA_OPTS="$(parse_jvm_options "$LS_JVM_OPTS") $LS_JAVA_OPTS"
        JAVA_OPTS=$LS_JAVA_OPTS

        # jruby launcher uses JAVACMD as its java executable and JAVA_OPTS as the JVM options
        export JAVACMD
        export JAVA_OPTS
      }

      setup_vendored_jruby() {
        JRUBY_BIN="${LOGSTASH_HOME}/vendor/jruby/bin/jruby"

        if [ ! -f "${JRUBY_BIN}" ] ; then
          echo "Unable to find JRuby."
          echo "If you are a user, this is a bug."
          echo "If you are a developer, please run 'rake bootstrap'. Running 'rake' requires the 'ruby' program be available."
          exit 1
        fi

        if [ -z "$LS_GEM_HOME" ] ; then
          export GEM_HOME="${LOGSTASH_HOME}/vendor/bundle/jruby/2.3.0"
        else
          export GEM_HOME=${LS_GEM_HOME}
        fi
        if [ "$DEBUG" ] ; then
          echo "Using GEM_HOME=${GEM_HOME}"
        fi

        if [ -z "$LS_GEM_PATH" ] ; then
          export GEM_PATH=${GEM_HOME}
        else
          export GEM_PATH=${LS_GEM_PATH}
        fi
        if [ "$DEBUG" ] ; then
          echo "Using GEM_PATH=${GEM_PATH}"
        fi
      }

      setup() {
        setup_java
        setup_vendored_jruby
      }

      ruby_exec() {
        if [ "$DEBUG" ] ; then
          echo "DEBUG: exec ${JRUBY_BIN} $@"
        fi
        exec "${JRUBY_BIN}" "$@"
      }
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
    exec_start "#{run_logstash_script} --path.settings /etc/logstash/"
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
  action :disable
end
