# frozen_string_literal: true

#
# CONSULTEMPLATE
#

default['consul_template']['config_path'] = '/etc/consul-template.d/conf'
default['consul_template']['template_path'] = '/etc/consul-template.d/templates'

#
# FIREWALL
#

# Allow communication on the loopback address (127.0.0.1 and ::1)
default['firewall']['allow_loopback'] = true

# Do not allow MOSH connections
default['firewall']['allow_mosh'] = false

# Do not allow WinRM (which wouldn't work on Linux anyway, but close the ports just to be sure)
default['firewall']['allow_winrm'] = false

# No communication via IPv6 at all
default['firewall']['ipv6_enabled'] = false

#
# LOGSTASH
#

home_directory = '/usr/local/logstash'
settings_directory = '/etc/logstash'
default['logstash']['path']['home'] = home_directory
default['logstash']['path']['bin'] = "#{home_directory}/bin"
default['logstash']['path']['settings'] = settings_directory
default['logstash']['path']['conf'] = "#{settings_directory}/conf.d"
default['logstash']['path']['plugins'] = "#{home_directory}/plugins"
default['logstash']['path']['data'] = '/var/lib/logstash'

default['logstash']['consul']['service_name'] = 'logs'

default['logstash']['service_name'] = 'logstash'

default['logstash']['service_user'] = 'logstash'
default['logstash']['service_group'] = 'logstash'

default['logstash']['version'] = '1:6.6.0-1'

#
# TELEGRAF
#

default['telegraf']['service_user'] = 'telegraf'
default['telegraf']['service_group'] = 'telegraf'
default['telegraf']['config_directory'] = '/etc/telegraf/telegraf.d'
