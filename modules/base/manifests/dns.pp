class base::dns (
  String $openvox_primary_fqdn = 'openvox-cli.lab.local',
  String $openvox_primary_ip   = '10.0.0.10',
) {
  file { '/etc/systemd/resolved.conf.d':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/etc/systemd/resolved.conf.d/dns.conf':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "[Resolve]\nDNS=10.0.0.11\nDomains=~lab.local\n",
    require => File['/etc/systemd/resolved.conf.d'],
    notify  => Service['systemd-resolved'],
  }

  service { 'systemd-resolved':
    ensure => running,
    enable => true,
  }

  # Pin the OpenVox primary in /etc/hosts so agent runs never depend on Pi-hole.
  # Pi-hole runs on the Docker host, which reboots nightly; agent runs during
  # that window failed with "Temporary failure in name resolution".
  host { $openvox_primary_fqdn:
    ensure => present,
    ip     => $openvox_primary_ip,
  }
}
