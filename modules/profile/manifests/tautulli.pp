# profile::tautulli
#
# Manages the Tautulli docker-compose deployment on cli-docker.
# Tautulli provides Plex analytics, play history, and notifications.
#
# Requires:
#   profile::docker     - Docker Engine + compose plugin
class profile::tautulli (
  String $plex_token    = '',
  String $puid          = '1026',
  String $pgid          = '100',
  String $tautulli_port = '8181',
  String $compose_user  = 'ubuntu',
  String $compose_dir   = '/home/ubuntu/docker/tautulli',
) {
  file { $compose_dir:
    ensure => directory,
    owner  => $compose_user,
    group  => $compose_user,
    mode   => '0755',
    require => File['/home/ubuntu/docker'],
  }

file { "${compose_dir}/config":
    ensure  => directory,
    owner   => $puid,
    group   => $pgid,
    mode    => '0755',
    require => File[$compose_dir],
  }

  file { "${compose_dir}/docker-compose.yml":
    ensure  => file,
    owner   => $compose_user,
    group   => $compose_user,
    mode    => '0644',
    content => template('profile/tautulli/docker-compose.yml.erb'),
    require => File[$compose_dir],
    notify  => Exec['tautulli_compose_up'],
  }

  exec { 'tautulli_compose_up':
    command     => '/usr/bin/docker compose up -d',
    cwd         => $compose_dir,
    user        => $compose_user,
    refreshonly => true,
    logoutput   => true,
    require     => File["${compose_dir}/docker-compose.yml"],
  }
}
