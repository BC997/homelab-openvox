# @summary Patch Wednesday: reboot this VM in its weekly slot, only if a reboot is pending.
#
# Installs /usr/local/sbin/patch-reboot plus a systemd service and timer.
# The timer fires once a week at $weekday $time (local time, set per node in hiera).
# The script reboots only when all of these are true:
#   - /var/run/reboot-required exists
#   - the dpkg locks (/var/lib/dpkg/lock-frontend, /var/lib/dpkg/lock) are free;
#     if one is held it rechecks every 5 min for up to 10 min, then skips
#   - the VM has been up at least min_uptime_minutes
# Persistent=false, so a VM that was off during its slot does not reboot when it boots.
# Results go to the journal: journalctl -u patch-reboot.service
# Manual check: sudo patch-reboot --dry-run (prints the decision, never reboots)
#
# Off by default. A node opts in from data/nodes/<certname>.yaml with
#   profile::patch_reboot::ensure: 'present'
#   profile::patch_reboot::time: 'HH:MM'
# Lives next to profile::reboot_watch, which watches the same flag file.
class profile::patch_reboot (
  Enum['present', 'absent']                         $ensure             = 'absent',
  Enum['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'] $weekday        = 'Wed',
  Pattern[/\A([01][0-9]|2[0-3]):[0-5][0-9]\z/]      $time               = '03:30',
  Integer[0]                                        $min_uptime_minutes = 30,
) {
  $script  = '/usr/local/sbin/patch-reboot'
  $service = '/etc/systemd/system/patch-reboot.service'
  $timer   = '/etc/systemd/system/patch-reboot.timer'

  $service_content = @("SERVICE")
    # Managed by Open Source Puppet (profile::patch_reboot)
    [Unit]
    Description=Patch Wednesday: reboot only if /var/run/reboot-required exists

    [Service]
    Type=oneshot
    Environment=MIN_UPTIME_MINUTES=${min_uptime_minutes}
    ExecStart=${script}
    # Room for the 10 minute dpkg lock retry
    TimeoutStartSec=20min
    SyslogIdentifier=patch-reboot
    | SERVICE

  $timer_content = @("TIMER")
    # Managed by Open Source Puppet (profile::patch_reboot)
    [Unit]
    Description=Patch Wednesday slot (${weekday} ${time})

    [Timer]
    OnCalendar=${weekday} *-*-* ${time}:00
    Persistent=false
    AccuracySec=1min

    [Install]
    WantedBy=timers.target
    | TIMER

  exec { 'patch-reboot-daemon-reload':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
  }

  if $ensure == 'present' {
    file { $script:
      ensure => file,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
      source => 'puppet:///modules/profile/patch_reboot/patch-reboot',
    }

    file { $service:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => $service_content,
      notify  => Exec['patch-reboot-daemon-reload'],
    }

    file { $timer:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => $timer_content,
      notify  => Exec['patch-reboot-daemon-reload'],
    }

    service { 'patch-reboot.timer':
      ensure    => running,
      enable    => true,
      require   => [
        File[$script],
        File[$service],
        Exec['patch-reboot-daemon-reload'],
      ],
      subscribe => File[$timer],
    }
  } else {
    # Only acts if the timer was installed before, so nodes that never had it
    # show no changes in noop.
    exec { 'patch-reboot-timer-off':
      command => '/usr/bin/systemctl disable --now patch-reboot.timer',
      onlyif  => "/usr/bin/test -f ${timer}",
    }

    file { [$timer, $service, $script]:
      ensure  => absent,
      require => Exec['patch-reboot-timer-off'],
      notify  => Exec['patch-reboot-daemon-reload'],
    }
  }
}
