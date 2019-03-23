Describe 'The logstash application' {
    Context 'is installed' {
        It 'with binaries in /usr/share/logstash' {
            '/usr/share/logstash' | Should Exist
            '/usr/share/logstash/bin' | Should Exist
        }

        It 'with configurations in /etc/logstash' {
            '/etc/logstash' | Should Exist
            '/etc/logstash/conf.d' | Should Exist
        }
    }

    Context 'has been daemonized' {
        $serviceConfigurationPath = '/etc/systemd/system/logstash.service'
        if (-not (Test-Path $serviceConfigurationPath))
        {
            It 'has a systemd configuration' {
               $false | Should Be $true
            }
        }

        $expectedContent = @'
[Service]
Type = forking
PIDFile = /tmp/logstash_pid
ExecStart = /usr/share/logstash/run_logstash.sh --path.settings /etc/logstash/
RestartSec = 5
Restart = always
User = logstash
Nice = 19
EnvironmentFile = -/etc/sysconfig/logstash
LimitNOFILE = 16384

[Unit]
Description = Logstash
Documentation = https://elastic.co
Requires = network-online.target
After = network-online.target
StartLimitIntervalSec = 0

[Install]
WantedBy = multi-user.target

'@
        $serviceFileContent = Get-Content $serviceConfigurationPath | Out-String
        $systemctlOutput = & systemctl status logstash
        It 'with a systemd service' {
            $serviceFileContent | Should Be ($expectedContent -replace "`r", "")

            $systemctlOutput | Should Not Be $null
            $systemctlOutput.GetType().FullName | Should Be 'System.Object[]'
            $systemctlOutput.Length | Should BeGreaterThan 3
            $systemctlOutput[0] | Should Match 'logstash.service - Logstash'
        }

        It 'that is enabled' {
            $systemctlOutput[1] | Should Match 'Loaded:\sloaded\s\(.*;\senabled;.*\)'

        }

        It 'and is running' {
            $systemctlOutput[2] | Should Match 'Active:\sactive\s\(running\).*'
        }
    }
}
