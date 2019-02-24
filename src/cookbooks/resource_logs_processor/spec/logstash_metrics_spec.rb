# frozen_string_literal: true

require 'spec_helper'

logstash_metrics_port = 9600

describe 'resource_logs_processor::logstash_metrics' do
  context 'adds the consul-template files for the telegraf input' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    telegraf_logstash_template_content = <<~CONF
      # Telegraf Configuration

      ###############################################################################
      #                            INPUT PLUGINS                                    #
      ###############################################################################

      [[inputs.http]]
        ## One or more URLs from which to read formatted metrics
        urls = [
          "http://localhost:#{logstash_metrics_port}/_node/stats/jvm"
        ]

        ## HTTP method
        # method = "GET"

        ## Optional HTTP headers
        # headers = {"X-Special-Header" = "Special-Value"}

        ## HTTP entity-body to send with POST/PUT requests.
        # body = ""

        ## HTTP Content-Encoding for write request body, can be set to "gzip" to
        ## compress body or "identity" to apply no encoding.
        # content_encoding = "identity"

        ## Optional HTTP Basic Auth Credentials
        # username = ""
        # password = ""

        ## Optional TLS Config
        # tls_ca = "/etc/telegraf/ca.pem"
        # tls_cert = "/etc/telegraf/cert.pem"
        # tls_key = "/etc/telegraf/key.pem"
        ## Use TLS but skip chain & host verification
        # insecure_skip_verify = false

        ## Amount of time allowed to complete the HTTP request
        # timeout = "5s"

        ## Data format to consume.
        ## Each data format has its own unique set of configuration options, read
        ## more about them here:
        ## https://github.com/influxdata/telegraf/blob/master/docs/DATA_FORMATS_INPUT.md
        data_format = "json"

        [inputs.http.tags]
          influxdb_database = "{{ keyOrDefault "config/services/metrics/databases/services" "services" }}"
          service = "logstash"
    CONF
    it 'creates telegraf logstash template file in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/templates/telegraf_logstash_inputs.ctmpl')
        .with_content(telegraf_logstash_template_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end

    consul_template_telegraf_logstash_configuration_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This is the source file on disk to use as the input template. This is often
        # called the "Consul Template template". This option is required if not using
        # the `contents` option.
        source = "/etc/consul-template.d/templates/telegraf_logstash_inputs.ctmpl"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/etc/telegraf/telegraf.d/inputs_logstash.conf"

        # This options tells Consul Template to create the parent directories of the
        # destination path if they do not exist. The default value is true.
        create_dest_dirs = false

        # This is the optional command to run when the template is rendered. The
        # command will only run if the resulting template changes. The command must
        # return within 30s (configurable), and it must have a successful exit code.
        # Consul Template is not a replacement for a process monitor or init system.
        command = "/bin/bash -c 'chown telegraf:telegraf /etc/telegraf/telegraf.d/inputs_logstash.conf && systemctl restart telegraf'"

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
    it 'creates telegraf_logstash_inputs.hcl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/telegraf_logstash_inputs.hcl')
        .with_content(consul_template_telegraf_logstash_configuration_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end
  end
end
