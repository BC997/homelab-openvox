class base::ssh {
  $ssh_service_name = $facts['os']['distro']['codename'] ? {
    'noble'  => 'ssh',
    default  => 'ssh.socket',
  }

  file { '/etc/ssh/sshd_config':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => template('base/sshd_config.erb'),
    require => Package['openssh-server'],
    notify  => Service[$ssh_service_name],
  }

  service { $ssh_service_name:
    ensure  => running,
    enable  => true,
    require => Package['openssh-server'],
  }
}
