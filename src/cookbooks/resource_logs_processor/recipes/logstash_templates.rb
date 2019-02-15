# frozen_string_literal: true

#
# Cookbook Name:: resource_logs_processor
# Recipe:: logstash_templates
#
# Copyright 2019, P. van der Velde
#

consul_template_config_path = node['consul_template']['config_path']
consul_template_template_path = node['consul_template']['template_path']

logstash_filters_directory = node['logstash']['path']['conf']
logstash_filters_script_template_file = node['logstash']['consul_template']['provisioning_filters_script']

# This one is tricky because the Consul K-V contents has to be the template file for
# Consul-Template to read because we need credentials for RabbitMQ, Elasticsearch and
# potentially others. But Consul-Template cannot create new template files for itself
# because it will never read them after it has started, i.e. a restart or SIGHUP is
# required.
#
# So we create the CTMPL file and the HCL file and then send a SIGHUP to Consul-Template.
# The drawback is that we will leave templates that used to exist but don't anymore.
file "#{consul_template_template_path}/#{logstash_filters_script_template_file}" do
  action :create
  content <<~CONF
    #!/bin/sh

    {{ range ls "config/services/logs/filters" }}
    cat <<EOT > #{consul_template_template_path}/logstash_filter_{{ .Key }}.ctmpl
    {{ .Value }}
    EOT

    cat <<EOT > #{consul_template_config_path}/logstash_filter_{{ .Key }}.hcl
    template {
      source = "#{consul_template_template_path}/logstash_filter_{{ .Key }}.ctmpl"
      destination = "#{logstash_filters_directory}/logstash_filter_{{ .Key }}.conf"
      create_dest_dirs = false
      command = ""
      command_timeout = "15s"
      error_on_missing_key = false
      perms = 0550
      backup = true
      wait {
        min = "2s"
        max = "10s"
      }
    }
    EOT
    {{ end }}
  CONF
  group 'root'
  mode '0550'
  owner 'root'
end

consul_template_data_path = node['consul_template']['data_path']
logstash_filters_script = '/tmp/logstash_filters.sh'
file "#{consul_template_config_path}/logstash_filters.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{logstash_filters_script_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{logstash_filters_script}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "/bin/bash -c 'sh #{logstash_filters_script} && kill -HUP `cat #{consul_template_data_path}/pid`'"

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
  HCL
  group 'root'
  mode '0550'
  owner 'root'
end
