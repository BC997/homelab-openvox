# @summary Alert Home Assistant about failed Open Source Puppet runs and drift corrections.
#
# Installs /usr/local/bin/puppet-report-alert plus a systemd service and timer.
# Each run reads OpenVoxDB on localhost for reports newer than the last one seen,
# and posts failed runs, plus changes made more than deploy_grace minutes after
# the last r10k deploy, to a LAN only Home Assistant webhook.
# Results go to the journal: journalctl -u puppet-report-alert.service
#
# The webhook URL comes from per node eyaml and is written to a root only
# env file, never into the unit or the Open Source Puppet reports.
# Set ensure to 'absent' to remove the script, units, timer and env file.
class profile::puppet_report_alert (
  String $ha_webhook_url,
  Enum['present', 'absent'] $ensure = 'present',
  String $interval                  = '5min',
  Integer $deploy_grace             = 45,
  String $pdb_url                   = 'http://localhost:8080',
  String $deploy_file               = '/etc/puppet/code/environments/production/.r10k-deploy.json',
) {
  $script   = '/usr/local/bin/puppet-report-alert'
  $env_file = '/etc/default/puppet-report-alert'
  $service  = '/etc/systemd/system/puppet-report-alert.service'
  $timer    = '/etc/systemd/system/puppet-report-alert.timer'

  $env_content = @("ENV")
    # Managed by Open Source Puppet (profile::puppet_report_alert)
    HA_WEBHOOK_URL=${ha_webhook_url}
    PDB_URL=${pdb_url}
    DEPLOY_FILE=${deploy_file}
    DEPLOY_GRACE_MIN=${deploy_grace}
    | ENV

  $service_content = @("SERVICE")
    # Managed by Open Source Puppet (profile::puppet_report_alert)
    [Unit]
    Description=Send Open Source Puppet failures and drift corrections to Home Assistant
    Wants=network-online.target
    After=network-online.target

    [Service]
    Type=oneshot
    EnvironmentFile=${env_file}
    ExecStart=${script}
    SyslogIdentifier=puppet-report-alert
    | SERVICE

  $timer_content = @("TIMER")
    # Managed by Open Source Puppet (profile::puppet_report_alert)
    [Unit]
    Description=Check OpenVoxDB for new reports every ${interval}

    [Timer]
    OnBootSec=5min
    OnUnitActiveSec=${interval}
    AccuracySec=30s

    [Install]
    WantedBy=timers.target
    | TIMER

  exec { 'puppet-report-alert-daemon-reload':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
  }

  if $ensure == 'present' {
    package { 'python3':
      ensure => installed,
    }

    file { '/var/lib/puppet-report-alert':
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0700',
    }

    file { $script:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      source  => 'puppet:///modules/profile/puppet_report_alert/puppet-report-alert',
      require => Package['python3'],
    }

    file { $env_file:
      ensure    => file,
      owner     => 'root',
      group     => 'root',
      mode      => '0600',
      content   => Sensitive($env_content),
      show_diff => false,
    }

    file { $service:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => $service_content,
      notify  => Exec['puppet-report-alert-daemon-reload'],
    }

    file { $timer:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => $timer_content,
      notify  => Exec['puppet-report-alert-daemon-reload'],
    }

    service { 'puppet-report-alert.timer':
      ensure    => running,
      enable    => true,
      require   => [
        File[$script],
        File[$env_file],
        File[$service],
        File['/var/lib/puppet-report-alert'],
        Exec['puppet-report-alert-daemon-reload'],
      ],
      subscribe => File[$timer],
    }
  } else {
    service { 'puppet-report-alert.timer':
      ensure => stopped,
      enable => false,
    }

    file { [$timer, $service, $script, $env_file]:
      ensure  => absent,
      require => Service['puppet-report-alert.timer'],
      notify  => Exec['puppet-report-alert-daemon-reload'],
    }
  }
}
