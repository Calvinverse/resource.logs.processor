# frozen_string_literal: true

require 'spec_helper'

describe 'resource_logs_processor::logstash_templates' do
  context 'create the logstash config template' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    logstash_yml_content = <<~SCRIPT
      cat <<'EOT' > /etc/logstash/logstash.yml
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
      # When enabled, process escaped characters in the
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
      xpack.monitoring.enabled: true
      #xpack.monitoring.elasticsearch.username: logstash_system
      #xpack.monitoring.elasticsearch.password: password
      xpack.monitoring.elasticsearch.url: ["http://{{ keyOrDefault "config/services/documents/protocols/http/host" "unknown" }}.service.{{ keyOrDefault "config/services/consul/domain" "unknown" }}:{{ keyOrDefault "config/services/documents/protocols/http/port" "80" }}"]
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
      EOT

      chown logstash:logstash /etc/logstash/logstash.yml
      chmod 550 /etc/logstash/logstash.yml

      if ( ! $(systemctl is-enabled --quiet logstash) ); then
        systemctl enable logstash

        while true; do
          if ( (systemctl is-enabled --quiet logstash) ); then
              break
          fi

          sleep 1
        done
      fi

      if ( ! (systemctl is-active --quiet logstash) ); then
        systemctl start logstash

        while true; do
          if ( (systemctl is-active --quiet logstash) ); then
              break
          fi

          sleep 1
        done
      fi
    SCRIPT
    it 'creates logstash configuration template file in the configuration directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/templates/logstash_config.ctmpl')
        .with_content(logstash_yml_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end

    consul_template_logstash_config_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This is the source file on disk to use as the input template. This is often
        # called the "Consul Template template". This option is required if not using
        # the `contents` option.
        source = "/etc/consul-template.d/templates/logstash_config.ctmpl"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/tmp/logstash_config.sh"

        # This options tells Consul Template to create the parent directories of the
        # destination path if they do not exist. The default value is true.
        create_dest_dirs = false

        # This is the optional command to run when the template is rendered. The
        # command will only run if the resulting template changes. The command must
        # return within 30s (configurable), and it must have a successful exit code.
        # Consul Template is not a replacement for a process monitor or init system.
        command = "sh /tmp/logstash_config.sh"

        # This is the maximum amount of time to wait for the optional command to
        # return. Default is 30s.
        command_timeout = "15s"

        # Exit with an error when accessing a struct or map field/key that does not
        # exist. The default behavior will print "<no value>" when accessing a field
        # that does not exist. It is highly recommended you set this to "true" when
        # retrieving secrets from Vault.
        error_on_missing_key = false

        # This is the permission to render the file. If this option is left
        # unspecified, Consul Template will attempt to match the permissions of the
        # file that already exists at the destination path. If no file exists at that
        # path, the permissions are 0644.
        perms = 0550

        # This option backs up the previously rendered template at the destination
        # path before writing a new one. It keeps exactly one backup. This option is
        # useful for preventing accidental changes to the data without having a
        # rollback strategy.
        backup = true

        # These are the delimiters to use in the template. The default is "{{" and
        # "}}", but for some templates, it may be easier to use a different delimiter
        # that does not conflict with the output file itself.
        left_delimiter  = "{{"
        right_delimiter = "}}"

        # This is the `minimum(:maximum)` to wait before rendering a new template to
        # disk and triggering a command, separated by a colon (`:`). If the optional
        # maximum value is omitted, it is assumed to be 4x the required minimum value.
        # This is a numeric time with a unit suffix ("5s"). There is no default value.
        # The wait value for a template takes precedence over any globally-configured
        # wait.
        wait {
          min = "2s"
          max = "10s"
        }
      }
    CONF
    it 'creates logstash_config.hcl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/logstash_config.hcl')
        .with_content(consul_template_logstash_config_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end
  end

  context 'creates the template files for the logstash filters' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    logstash_filters_script_template_file_content = <<~CONF
      #!/bin/sh

      {{ range ls "config/services/logs/filters" }}
      cat <<EOT > /etc/consul-template.d/templates/{{ .Key }}.ctmpl
      {{ .Value }}
      EOT

      cat <<EOT > /etc/consul-template.d/conf/{{ .Key }}.hcl
      template {
        source = "/etc/consul-template.d/templates/{{ .Key }}.ctmpl"
        destination = "/etc/logstash/conf.d/{{ .Key }}.conf"
        create_dest_dirs = false
        command = "/bin/bash -c 'chown logstash:logstash /etc/logstash/conf.d/{{ .Key }}.conf'"
        command_timeout = "15s"
        error_on_missing_key = false
        perms = 0550
        backup = false
        wait {
          min = "2s"
          max = "10s"
        }
      }
      EOT
      {{ end }}
    CONF
    it 'creates logstash filters script template file in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/templates/logstash_filters.ctmpl')
        .with_content(logstash_filters_script_template_file_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end

    consul_template_logstash_filters_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This is the source file on disk to use as the input template. This is often
        # called the "Consul Template template". This option is required if not using
        # the `contents` option.
        source = "/etc/consul-template.d/templates/logstash_filters.ctmpl"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/tmp/logstash_filters.sh"

        # This options tells Consul Template to create the parent directories of the
        # destination path if they do not exist. The default value is true.
        create_dest_dirs = false

        # This is the optional command to run when the template is rendered. The
        # command will only run if the resulting template changes. The command must
        # return within 30s (configurable), and it must have a successful exit code.
        # Consul Template is not a replacement for a process monitor or init system.
        command = "/bin/bash -c 'sh /tmp/logstash_filters.sh && kill -HUP `cat /etc/consul-template.d/data/pid`'"

        # This is the maximum amount of time to wait for the optional command to
        # return. Default is 30s.
        command_timeout = "15s"

        # Exit with an error when accessing a struct or map field/key that does not
        # exist. The default behavior will print "<no value>" when accessing a field
        # that does not exist. It is highly recommended you set this to "true" when
        # retrieving secrets from Vault.
        error_on_missing_key = false

        # This is the permission to render the file. If this option is left
        # unspecified, Consul Template will attempt to match the permissions of the
        # file that already exists at the destination path. If no file exists at that
        # path, the permissions are 0644.
        perms = 0550

        # This option backs up the previously rendered template at the destination
        # path before writing a new one. It keeps exactly one backup. This option is
        # useful for preventing accidental changes to the data without having a
        # rollback strategy.
        backup = true

        # These are the delimiters to use in the template. The default is "{{" and
        # "}}", but for some templates, it may be easier to use a different delimiter
        # that does not conflict with the output file itself.
        left_delimiter  = "{{"
        right_delimiter = "}}"

        # This is the `minimum(:maximum)` to wait before rendering a new template to
        # disk and triggering a command, separated by a colon (`:`). If the optional
        # maximum value is omitted, it is assumed to be 4x the required minimum value.
        # This is a numeric time with a unit suffix ("5s"). There is no default value.
        # The wait value for a template takes precedence over any globally-configured
        # wait.
        wait {
          min = "2s"
          max = "10s"
        }
      }
    CONF
    it 'creates logstash_filters.hcl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/logstash_filters.hcl')
        .with_content(consul_template_logstash_filters_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end
  end
end
