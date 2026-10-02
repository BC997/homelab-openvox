class base::dns {
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
}
