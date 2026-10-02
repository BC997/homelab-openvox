class profile::docker {
  # Docker GPG key
  file { '/etc/apt/keyrings':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  exec { 'download-docker-gpg-key':
    command => '/usr/bin/curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc',
    creates => '/etc/apt/keyrings/docker.asc',
    require => File['/etc/apt/keyrings'],
  }

  file { '/etc/apt/sources.list.d/docker.list':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable\n",
    require => Exec['download-docker-gpg-key'],
    notify  => Exec['apt-update-docker'],
  }

  exec { 'apt-update-docker':
    command     => '/usr/bin/apt-get update',
    refreshonly => true,
    require     => File['/etc/apt/sources.list.d/docker.list'],
  }

  package { ['docker-ce', 'docker-ce-cli', 'containerd.io', 'docker-buildx-plugin', 'docker-compose-plugin']:
    ensure  => installed,
    require => Exec['apt-update-docker'],
  }

  service { 'docker':
    ensure  => running,
    enable  => true,
    require => Package['docker-ce'],
  }
}
