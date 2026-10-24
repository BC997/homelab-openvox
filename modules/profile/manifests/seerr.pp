# profile::seerr
#
# Manages the Seerr docker-compose deployment on cli-docker.
# Seerr is a request management and media discovery tool for Plex.
# (Successor to Overseerr and Jellyseerr, merged into a single project Feb 2026.)
#
# Compose file is rendered from a template using Hiera variables.
# Image version intentionally uses :latest - Watchtower handles upgrades.
# Container recreation is triggered only when the compose file content changes.
#
# Requires:
#   profile::docker - Docker Engine + compose plugin
class profile::seerr (
  String $timezone     = 'America/Los_Angeles',
  String $seerr_port   = '5055',
  String $compose_user = 'ubuntu',
  String $compose_dir  = '/home/ubuntu/docker/seerr',
) {
  file { $compose_dir:
    ensure => directory,
    owner  => $compose_user,
    group  => $compose_user,
    mode   => '0755',
  }

  file { "${compose_dir}/config":
    ensure  => directory,
    owner   => '1000',
    group   => '1000',
    mode    => '0755',
    require => File[$compose_dir],
  }

  file { "${compose_dir}/docker-compose.yml":
    ensure  => file,
    owner   => $compose_user,
    group   => $compose_user,
    mode    => '0644',
    content => template('profile/seerr/docker-compose.yml.erb'),
    require => File[$compose_dir],
    notify  => Exec['seerr_compose_up'],
  }

  exec { 'seerr_compose_up':
    command     => '/usr/bin/docker compose up -d',
    cwd         => $compose_dir,
    user        => $compose_user,
    refreshonly => true,
    logoutput   => true,
    require     => File["${compose_dir}/docker-compose.yml"],
  }
}
