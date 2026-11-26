# @summary After each boot, alert Home Assistant if any auto restart container on cli-docker stayed down.
#
# Installs /usr/local/bin/container-check plus a systemd service and timer.
# The timer runs once per boot, 5 minutes in (OnBootSec, no repeat). The script
# lists every container whose restart policy is unless-stopped or always,
# skips the names in $ignore, and rechecks every 60 seconds for $wait_minutes.
# If any are still not running, or fewer than $expected_count exist, it posts
# one report to a LAN only HA webhook. It never starts or changes a container.
# This catches a planned Patch Wednesday reboot and an unplanned one (fence,
# power loss) the same way, which is how Prometheus stayed down on Nov 24 2026.
#
# The webhook URL comes from data/nodes/cli-docker.lab.local.eyaml and is
# written to a root only env file, never into the unit or the reports.
# Results go to the journal: journalctl -u container-check.service
# Manual checks: sudo container-check --status, sudo container-check --test
class profile::container_check (
  Variant[String, Sensitive[String]] $ha_webhook_url,
  Enum['present', 'absent'] $ensure         = 'present',
  Integer[1]                $expected_count = 19,
  Array[String]             $ignore         = ['grafana', 'unifi-poller', 'loki', 'influxdb', 'promtail'],
  Integer[1]                $wait_minutes   = 10,
) {
  $script   = '/usr/local/bin/container-check'
  $env_file = '/etc/default/container-check'
  $service  = '/etc/systemd/system/container-check.service'
  $timer    = '/etc/systemd/system/container-check.timer'
  $ignore_s = join($ignore, ',')
  # Start timeout: the full recheck window plus 5 minutes of slack.
  $timeout_s = $wait_minutes * 60 + 300

  # The URL may arrive as Sensitive if lookup_options converts it (as
  # cli-docker.lab.local.yaml does for the arr API keys). Unwrap it only here;
  # the env file content is wrapped in Sensitive again below.
  $webhook_url = $ha_webhook_url ? {
    Sensitive => $ha_webhook_url.unwrap,
    default   => $ha_webhook_url,
  }

  $env_content = @("ENV")
    # Managed by Open Source Puppet (profile::container_check)
    HA_WEBHOOK_URL=${webhook_url}
    EXPECTED_COUNT=${expected_count}
    IGNORE=${ignore_s}
    WAIT_MINUTES=${wait_minutes}
    | ENV

  $service_content = @("SERVICE")
    # Managed by Open Source Puppet (profile::container_check)
    [Unit]
    Description=Check that every auto restart container came back after boot
    Wants=network-online.target
    After=network-online.target docker.service

    [Service]
    Type=oneshot
    EnvironmentFile=${env_file}
    ExecStart=${script}
    TimeoutStartSec=${timeout_s}
    SyslogIdentifier=container-check
    | SERVICE

  $timer_content = @("TIMER")
    # Managed by Open Source Puppet (profile::container_check)
    [Unit]
    Description=Run container-check once, 5 minutes after boot

    [Timer]
    OnBootSec=5min
    AccuracySec=1min

    [Install]
    WantedBy=timers.target
    | TIMER

  exec { 'container-check-daemon-reload':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
  }

  if $ensure == 'present' {
    file { $script:
      ensure => file,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
      source => 'puppet:///modules/profile/container_check/container-check',
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
      notify  => Exec['container-check-daemon-reload'],
    }

    file { $timer:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => $timer_content,
      notify  => Exec['container-check-daemon-reload'],
    }

    # Note: when Puppet first starts this timer, the 5 minute OnBootSec mark is
    # long past, so systemd runs the check once right away. That's expected and
    # harmless (read only), and it doubles as a first live test. Later runs
    # happen once per boot.
    service { 'container-check.timer':
      ensure    => running,
      enable    => true,
      require   => [
        File[$script],
        File[$env_file],
        File[$service],
        Exec['container-check-daemon-reload'],
      ],
      subscribe => File[$timer],
    }
  } else {
    service { 'container-check.timer':
      ensure => stopped,
      enable => false,
    }

    file { [$timer, $service, $script, $env_file]:
      ensure  => absent,
      require => Service['container-check.timer'],
      notify  => Exec['container-check-daemon-reload'],
    }
  }
}
