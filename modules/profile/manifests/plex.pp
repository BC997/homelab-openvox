class profile::plex (
  Integer $upgrade_hour   = 3,
  Integer $upgrade_minute = 0,
  String  $upgrade_log    = '/var/log/plex-upgrade.log',
  Integer $restart_sec    = 10,
) {
  # Plex GPG key (v2 - required for PMS 1.43.0+)
  exec { 'add-plex-gpg-key':
    command => '/bin/curl -L https://downloads.plex.tv/plex-keys/PlexSign.v2.key | /usr/bin/gpg --yes --dearmor -o /etc/apt/keyrings/plexmediaserver.v2.gpg',
    creates => '/etc/apt/keyrings/plexmediaserver.v2.gpg',
    user    => 'root',
  }
  # Remove old repo file if present
  file { '/etc/apt/sources.list.d/plexmediaserver.list':
    ensure => absent,
  }
  # Plex apt repo (new repo.plex.tv - required for PMS 1.43.0+)
  file { '/etc/apt/sources.list.d/plex.list':
    ensure  => present,
    content => "deb [signed-by=/etc/apt/keyrings/plexmediaserver.v2.gpg] https://repo.plex.tv/deb/ public main\n",
    require => Exec['add-plex-gpg-key'],
  }
  # Plex package
  package { 'plexmediaserver':
    ensure  => installed,
    require => File['/etc/apt/sources.list.d/plex.list'],
  }
  cron { 'plex-upgrade':
    command => "apt-get update && apt-get install --only-upgrade plexmediaserver -y >> ${upgrade_log} 2>&1",
    user    => 'root',
    hour    => $upgrade_hour,
    minute  => $upgrade_minute,
    require => Package['plexmediaserver'],
  }
  # systemd override for auto-restart
  file { '/etc/systemd/system/plexmediaserver.service.d':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
  }
  file { '/etc/systemd/system/plexmediaserver.service.d/override.conf':
    ensure  => present,
    content => "[Service]\nRestart=on-failure\nRestartSec=${restart_sec}\n",
    owner   => 'root',
    group   => 'root',
    require => File['/etc/systemd/system/plexmediaserver.service.d'],
    notify  => Service['plexmediaserver'],
  }
  # Plex service
  service { 'plexmediaserver':
    ensure  => running,
    enable  => true,
    require => Package['plexmediaserver'],
  }
  # NFS client package
  package { 'nfs-common':
    ensure => installed,
  }
  # NFS mount for Plex media
  file { '/mnt/nas':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
  }
  file { '/mnt/nas/plexmediaserver':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    require => File['/mnt/nas'],
  }
  mount { '/mnt/nas/plexmediaserver':
    ensure  => mounted,
    device  => '10.0.0.20:/volume1/PlexMediaServer',
    fstype  => 'nfs',
    options => 'defaults,_netdev,nofail,x-systemd.automount',
    require => [File['/mnt/nas/plexmediaserver'], Package['nfs-common']],
  }
}
