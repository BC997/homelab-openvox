# @summary plex-watch: reports real buffering and playback errors on REMOTE
#   Plex streams to Home Assistant, with the likely cause.
#
# Listens to Plex's local websocket, ignores pauses, play starts, resumes and
# seeks (each seek restarts the ignore window, so 10 second skips never
# alert), skips LAN viewers, and posts to the HA automation
# "Plex Stream Problem" (automation.plex_stream_problem, LAN only webhook).
# Follows the Plex log live, since Plex keeps only about 4 hours on disk.
#
# The Plex token is read from Plex's own Preferences.xml at run time by the
# service (runs as the plex user), so no token is stored in OpenVox.
#
# Objective 11, Nov 2026. Included from role::media_server (plex-cli only).
#
# @param ha_webhook_url
#   Full HA webhook URL (hiera, data/nodes/plex-cli.lab.local.eyaml).
#
# Checks on plex-cli:
#   sudo systemctl status plex-watch
#   sudo journalctl -u plex-watch | cat
#   sudo /usr/local/sbin/plex-watch --check
#   sudo /usr/local/sbin/plex-watch --test   (sends a TEST alert)
#
class profile::plex_watch (
  String $ha_webhook_url,
) {
  package { 'python3-websocket':
    ensure => installed,
  }

  file { '/usr/local/sbin/plex-watch':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/profile/plex_watch/plex-watch',
  }

  # Read by systemd (as root) before the service drops to the plex user.
  file { '/etc/default/plex-watch':
    ensure    => file,
    owner     => 'root',
    group     => 'root',
    mode      => '0600',
    show_diff => false,
    content   => Sensitive("# Managed by OpenVox (profile::plex_watch)\nHA_WEBHOOK_URL=${ha_webhook_url}\n"),
  }

  file { '/etc/systemd/system/plex-watch.service':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => @(UNIT),
      # Managed by OpenVox (profile::plex_watch)
      [Unit]
      Description=plex-watch: report remote Plex buffering and errors to Home Assistant
      After=network-online.target plexmediaserver.service
      Wants=network-online.target

      [Service]
      Type=simple
      User=plex
      Group=plex
      EnvironmentFile=/etc/default/plex-watch
      ExecStart=/usr/bin/python3 /usr/local/sbin/plex-watch
      Restart=always
      RestartSec=15
      NoNewPrivileges=yes
      ProtectSystem=strict
      ProtectHome=yes
      PrivateTmp=yes
      PrivateDevices=yes
      ProtectKernelTunables=yes
      ProtectKernelModules=yes
      ProtectControlGroups=yes
      RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX

      [Install]
      WantedBy=multi-user.target
      | UNIT
  }

  exec { 'plex-watch-daemon-reload':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
    subscribe   => File['/etc/systemd/system/plex-watch.service'],
  }

  service { 'plex-watch':
    ensure    => running,
    enable    => true,
    require   => [Package['python3-websocket'], Exec['plex-watch-daemon-reload']],
    subscribe => [
      File['/usr/local/sbin/plex-watch'],
      File['/etc/default/plex-watch'],
      File['/etc/systemd/system/plex-watch.service'],
    ],
  }
}
