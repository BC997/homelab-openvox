class profile::node_exporter (
  String $version     = '1.8.1',
  String $install_dir = '/usr/local/bin',
  String $extra_args  = '',
) {
  $archive      = "node_exporter-${version}.linux-amd64"
  $download_url = "https://github.com/prometheus/node_exporter/releases/download/v${version}/${archive}.tar.gz"

  user { 'node_exporter':
    ensure     => present,
    system     => true,
    shell      => '/bin/false',
    home       => '/home/node_exporter',
    managehome => false,
  }

  exec { 'install-node-exporter':
    command => "/usr/bin/curl -sL ${download_url} | /bin/tar -xz -C /tmp && /bin/cp /tmp/${archive}/node_exporter ${install_dir}/node_exporter && /bin/chmod 0755 ${install_dir}/node_exporter",
    creates => "${install_dir}/node_exporter",
    require => User['node_exporter'],
    notify  => Service['node_exporter'],
  }

  $exec_start = $extra_args ? {
    ''      => "${install_dir}/node_exporter",
    default => "${install_dir}/node_exporter ${extra_args}",
  }

  file { '/etc/systemd/system/node_exporter.service':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "[Unit]\nDescription=Node Exporter\nAfter=network.target\n\n[Service]\nUser=node_exporter\nExecStart=${exec_start}\n\n[Install]\nWantedBy=multi-user.target\n",
    notify  => Service['node_exporter'],
  }

  service { 'node_exporter':
    ensure  => running,
    enable  => true,
    require => [Exec['install-node-exporter'], File['/etc/systemd/system/node_exporter.service']],
  }
}
