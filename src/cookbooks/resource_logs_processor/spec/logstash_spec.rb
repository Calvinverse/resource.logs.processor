# frozen_string_literal: true

require 'spec_helper'

describe 'resource_logs_processor::logstash' do
  context 'creates the logstash directories' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the logstash install directory at /usr/local/logstash' do
      expect(chef_run).to create_directory('/usr/local/logstash').with(
        group: 'logstash',
        mode: '0550',
        owner: 'logstash'
      )
    end

    it 'creates the logstash install directory at /usr/local/logstash/bin' do
      expect(chef_run).to create_directory('/usr/local/logstash/bin').with(
        group: 'logstash',
        mode: '0550',
        owner: 'logstash'
      )
    end

    it 'creates the settings directory at /etc/logstash' do
      expect(chef_run).to create_directory('/etc/logstash').with(
        group: 'logstash',
        mode: '0550',
        owner: 'logstash'
      )
    end

    it 'creates the filters directory at /etc/logstash/conf.d' do
      expect(chef_run).to create_directory('/etc/logstash/conf.d').with(
        group: 'logstash',
        mode: '0550',
        owner: 'logstash'
      )
    end

    it 'creates the logstash plugins directory at /usr/local/logstash/plugins' do
      expect(chef_run).to create_directory('/usr/local/logstash/plugins').with(
        group: 'logstash',
        mode: '0550',
        owner: 'logstash'
      )
    end

    it 'creates the data directory at /var/lib/logstash' do
      expect(chef_run).to create_directory('/var/lib/logstash').with(
        group: 'logstash',
        mode: '0770',
        owner: 'logstash'
      )
    end
  end

  context 'installs logstash' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'installs the elastic apt repository' do
      expect(chef_run).to add_apt_repository('elastic-apt-repository').with(
        action: [:add],
        components: %w[main],
        distribution: 'stable',
        key: ['https://artifacts.elastic.co/GPG-KEY-elasticsearch'],
        uri: 'https://artifacts.elastic.co/packages/6.x/apt'
      )
    end

    it 'installs the logstash package' do
      expect(chef_run).to install_apt_package('logstash')
    end

    it 'disables the logstash service' do
      expect(chef_run).to disable_service('logstash')
    end
  end

  context 'writes the configuration files' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    jvm_options_content = <<~CONF
      ## JVM configuration

      # Xms represents the initial size of total heap space
      # Xmx represents the maximum size of total heap space

      #-Xms1g
      #-Xmx1g

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
    CONF
    it 'creates jvm.options in the configuratino directory' do
      expect(chef_run).to create_file('/etc/logstash/jvm.options')
        .with_content(jvm_options_content)
        .with(
          group: 'logstash',
          owner: 'logstash',
          mode: '0550'
        )
    end

    logstash_yml_content = <<~CONF
      # Settings file in YAML
      #
      # Settings can be specified either in hierarchical form, e.g.:
      #
      #   pipeline:
      #     batch:
      #       size: 125
      #       delay: 5
      #
      # Or as flat keys:
      #
      #   pipeline.batch.size: 125
      #   pipeline.batch.delay: 5
      #
      # ------------  Node identity ------------
      #
      # Use a descriptive name for the node:
      #
      # node.name: test
      #
      # If omitted the node name will default to the machine's host name
      #
      # ------------ Data path ------------------
      #
      # Which directory should be used by logstash and its plugins
      # for any persistent needs. Defaults to LOGSTASH_HOME/data
      #

      path.data: /var/lib/logstash

      #
      # ------------ Pipeline Settings --------------
      #
      # The ID of the pipeline.
      #
      # pipeline.id: main
      #
      # Set the number of workers that will, in parallel, execute the filters+outputs
      # stage of the pipeline.
      #
      # This defaults to the number of the host's CPU cores.
      #
      # pipeline.workers: 2
      #
      # How many events to retrieve from inputs before sending to filters+workers

      pipeline.batch.size: 125

      # How long to wait in milliseconds while polling for the next event
      # before dispatching an undersized batch to filters+outputs

      pipeline.batch.delay: 50

      # Force Logstash to exit during shutdown even if there are still inflight
      # events in memory. By default, logstash will refuse to quit until all
      # received events have been pushed to the outputs.
      #
      # WARNING: enabling this can lead to data loss during shutdown

      pipeline.unsafe_shutdown: true

      # ------------ Pipeline Configuration Settings --------------
      #
      # Where to fetch the pipeline configuration for the main pipeline
      #
      # path.config:
      #
      # Pipeline configuration string for the main pipeline
      #
      # config.string:
      #
      # At startup, test if the configuration is valid and exit (dry run)
      #
      # config.test_and_exit: false
      #
      # Periodically check if the configuration has changed and reload the pipeline
      # This can also be triggered manually through the SIGHUP signal

      config.reload.automatic: true

      # How often to check if the pipeline configuration has changed (in seconds)

      config.reload.interval: 5s

      # Show fully compiled configuration as debug log message
      # NOTE: --log.level must be 'debug'
      #
      # config.debug: false
      #
      # When enabled, process escaped characters such as \\n and \\" in strings in the
      # pipeline configuration files.
      #
      # config.support_escapes: false
      #
      # ------------ Module Settings ---------------
      # Define modules here.  Modules definitions must be defined as an array.
      # The simple way to see this is to prepend each `name` with a `-`, and keep
      # all associated variables under the `name` they are associated with, and
      # above the next, like this:
      #
      # modules:
      #   - name: MODULE_NAME
      #     var.PLUGINTYPE1.PLUGINNAME1.KEY1: VALUE
      #     var.PLUGINTYPE1.PLUGINNAME1.KEY2: VALUE
      #     var.PLUGINTYPE2.PLUGINNAME1.KEY1: VALUE
      #     var.PLUGINTYPE3.PLUGINNAME3.KEY1: VALUE
      #
      # Module variable names must be in the format of
      #
      # var.PLUGIN_TYPE.PLUGIN_NAME.KEY
      #
      # modules:
      #
      # ------------ Cloud Settings ---------------
      # Define Elastic Cloud settings here.
      # Format of cloud.id is a base64 value e.g. dXMtZWFzdC0xLmF3cy5mb3VuZC5pbyRub3RhcmVhbCRpZGVudGlmaWVy
      # and it may have an label prefix e.g. staging:dXMtZ...
      # This will overwrite 'var.elasticsearch.hosts' and 'var.kibana.host'
      # cloud.id: <identifier>
      #
      # Format of cloud.auth is: <user>:<pass>
      # This is optional
      # If supplied this will overwrite 'var.elasticsearch.username' and 'var.elasticsearch.password'
      # If supplied this will overwrite 'var.kibana.username' and 'var.kibana.password'
      # cloud.auth: elastic:<password>
      #
      # ------------ Queuing Settings --------------
      #
      # Internal queuing model, "memory" for legacy in-memory based queuing and
      # "persisted" for disk-based acked queueing. Defaults is memory

      queue.type: memory

      # If using queue.type: persisted, the directory path where the data files will be stored.
      # Default is path.data/queue
      #
      # path.queue:
      #
      # If using queue.type: persisted, the page data files size. The queue data consists of
      # append-only data files separated into pages. Default is 64mb
      #
      # queue.page_capacity: 64mb
      #
      # If using queue.type: persisted, the maximum number of unread events in the queue.
      # Default is 0 (unlimited)
      #
      # queue.max_events: 0
      #
      # If using queue.type: persisted, the total capacity of the queue in number of bytes.
      # If you would like more unacked events to be buffered in Logstash, you can increase the
      # capacity using this setting. Please make sure your disk drive has capacity greater than
      # the size specified here. If both max_bytes and max_events are specified, Logstash will pick
      # whichever criteria is reached first
      # Default is 1024mb or 1gb
      #
      # queue.max_bytes: 1024mb
      #
      # If using queue.type: persisted, the maximum number of acked events before forcing a checkpoint
      # Default is 1024, 0 for unlimited
      #
      # queue.checkpoint.acks: 1024
      #
      # If using queue.type: persisted, the maximum number of written events before forcing a checkpoint
      # Default is 1024, 0 for unlimited
      #
      # queue.checkpoint.writes: 1024
      #
      # If using queue.type: persisted, the interval in milliseconds when a checkpoint is forced on the head page
      # Default is 1000, 0 for no periodic checkpoint.
      #
      # queue.checkpoint.interval: 1000
      #
      # ------------ Dead-Letter Queue Settings --------------
      # Flag to turn on dead-letter queue.
      #
      # dead_letter_queue.enable: false

      # If using dead_letter_queue.enable: true, the maximum size of each dead letter queue. Entries
      # will be dropped if they would increase the size of the dead letter queue beyond this setting.
      # Default is 1024mb
      # dead_letter_queue.max_bytes: 1024mb

      # If using dead_letter_queue.enable: true, the directory path where the data files will be stored.
      # Default is path.data/dead_letter_queue
      #
      # path.dead_letter_queue:
      #
      # ------------ Metrics Settings --------------
      #
      # Bind address for the metrics REST endpoint

      http.host: "127.0.0.1"

      # Bind port for the metrics REST endpoint, this option also accept a range
      # (9600-9700) and logstash will pick up the first available ports.

      http.port: 9600

      # ------------ Debugging Settings --------------
      #
      # Options for log.level:
      #   * fatal
      #   * error
      #   * warn
      #   * info (default)
      #   * debug
      #   * trace
      #
      # log.level: info
      path.logs: /var/log/logstash
      #
      # ------------ Other Settings --------------
      #
      # Where to find custom plugins
      # path.plugins: []
      #
      # ------------ X-Pack Settings (not applicable for OSS build)--------------
      #
      # X-Pack Monitoring
      # https://www.elastic.co/guide/en/logstash/current/monitoring-logstash.html
      #xpack.monitoring.enabled: false
      #xpack.monitoring.elasticsearch.username: logstash_system
      #xpack.monitoring.elasticsearch.password: password
      #xpack.monitoring.elasticsearch.url: ["https://es1:9200", "https://es2:9200"]
      #xpack.monitoring.elasticsearch.ssl.ca: [ "/path/to/ca.crt" ]
      #xpack.monitoring.elasticsearch.ssl.truststore.path: path/to/file
      #xpack.monitoring.elasticsearch.ssl.truststore.password: password
      #xpack.monitoring.elasticsearch.ssl.keystore.path: /path/to/file
      #xpack.monitoring.elasticsearch.ssl.keystore.password: password
      #xpack.monitoring.elasticsearch.ssl.verification_mode: certificate
      #xpack.monitoring.elasticsearch.sniffing: false
      #xpack.monitoring.collection.interval: 10s
      #xpack.monitoring.collection.pipeline.details.enabled: true
      #
      # X-Pack Management
      # https://www.elastic.co/guide/en/logstash/current/logstash-centralized-pipeline-management.html
      #xpack.management.enabled: false
      #xpack.management.pipeline.id: ["main", "apache_logs"]
      #xpack.management.elasticsearch.username: logstash_admin_user
      #xpack.management.elasticsearch.password: password
      #xpack.management.elasticsearch.url: ["https://es1:9200", "https://es2:9200"]
      #xpack.management.elasticsearch.ssl.ca: [ "/path/to/ca.crt" ]
      #xpack.management.elasticsearch.ssl.truststore.path: /path/to/file
      #xpack.management.elasticsearch.ssl.truststore.password: password
      #xpack.management.elasticsearch.ssl.keystore.path: /path/to/file
      #xpack.management.elasticsearch.ssl.keystore.password: password
      #xpack.management.elasticsearch.ssl.verification_mode: certificate
      #xpack.management.elasticsearch.sniffing: false
      #xpack.management.logstash.poll_interval: 5s
    CONF
    it 'creates logstash.yml in the configuration directory' do
      expect(chef_run).to create_file('/etc/logstash/logstash.yml')
        .with_content(logstash_yml_content)
        .with(
          group: 'logstash',
          owner: 'logstash',
          mode: '0550'
        )
    end

    log4j2_properties_content = <<~CONF
      log4j.rootLogger=INFO, SYSLOG

      log4j.appender.SYSLOG=com.github.loggly.log4j.SyslogAppender64k
      log4j.appender.SYSLOG.SyslogHost=localhost
      log4j.appender.SYSLOG.Facility=Local0
      log4j.appender.SYSLOG.Header=true
      log4j.appender.SYSLOG.layout=org.apache.log4j.EnhancedPatternLayout
      log4j.appender.SYSLOG.layout.ConversionPattern=java %d{ISO8601}{GMT} %p %t %c %M - %m%n
    CONF
    it 'creates log4j2.properties in the configuration directory' do
      expect(chef_run).to create_file('/etc/logstash/log4j2.properties')
        .with_content(log4j2_properties_content)
        .with(
          group: 'logstash',
          owner: 'logstash',
          mode: '0550'
        )
    end
  end
end
