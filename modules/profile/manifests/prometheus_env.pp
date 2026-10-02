class profile::prometheus_env (
  String $pve_user       = 'Prometheus@pve',
  String $pve_password   = '',
  String $pve_verify_ssl = 'false',
) {
  file { '/home/ubuntu/docker/prometheus':
    ensure => directory,
    owner  => 'ubuntu',
    group  => 'docker',
    mode   => '0750',
  }

  file { '/home/ubuntu/docker/prometheus/.env':
    ensure  => present,
    owner   => 'ubuntu',
    group   => 'ubuntu',
    mode    => '0640',
    content => "PVE_USER=${pve_user}\nPVE_PASSWORD=${pve_password}\nPVE_VERIFY_SSL=${pve_verify_ssl}\n",
    require => File['/home/ubuntu/docker/prometheus'],
  }
}
