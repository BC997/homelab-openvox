# profile::arr_stack
#
# Manages the arr stack docker-compose deployment on cli-docker.
# Stack consists of: Sonarr, Radarr, Audiobookshelf, Lidarr, Bazarr, Prowlarr.
#
# Compose file is rendered from a template using Hiera variables.
# Image versions intentionally use :latest - Watchtower handles upgrades.
# Container recreation is triggered only when the compose file content changes.
#
# Requires:
#   profile::docker     - Docker Engine + compose plugin
#   profile::nfs_media  - NFS mount at /mnt/nas/plexmediaserver

class profile::arr_stack (
  String $puid          = '1026',
  String $pgid          = '100',
  String $timezone      = 'America/Los_Angeles',
  String $media_path    = '/mnt/nas/plexmediaserver',
  String $sonarr_port   = '8082',
  String $radarr_port   = '7878',
  String $abs_port      = '90',
  String $bazarr_port   = '6767',
  String $prowlarr_port = '9696',
  String $lidarr_port   = '8686',
  String $compose_user  = 'ubuntu',
  String $compose_dir   = '/home/ubuntu/docker/arrs',
) {

  # Parent docker directory (in case it doesn't exist - normally created when ubuntu user logs in)
  file { '/home/ubuntu/docker':
    ensure => directory,
    owner  => $compose_user,
    group  => $compose_user,
    mode   => '0755',
  }

  # Stack root directory
  file { $compose_dir:
    ensure  => directory,
    owner   => $compose_user,
    group   => $compose_user,
    mode    => '0755',
    require => File['/home/ubuntu/docker'],
  }


  # Per-service config directories (created if missing, ignored otherwise)
  $config_dirs = [
    "${compose_dir}/sonarr",
    "${compose_dir}/sonarr/config",
    "${compose_dir}/radarr",
    "${compose_dir}/radarr/config",
    "${compose_dir}/audiobookshelf",
    "${compose_dir}/audiobookshelf/config",
    "${compose_dir}/audiobookshelf/metadata",
    "${compose_dir}/lidarr",
    "${compose_dir}/lidarr/config",
    "${compose_dir}/bazarr",
    "${compose_dir}/bazarr/config",
    "${compose_dir}/prowlarr",
    "${compose_dir}/prowlarr/config",
  ]

 file { $config_dirs:
    ensure  => directory,
    owner   => $puid,
    group   => $pgid,
    mode    => '0755',
    require => File[$compose_dir],
  }

  # The compose file itself, rendered from template
  file { "${compose_dir}/docker-compose.yml":
    ensure  => file,
    owner   => $compose_user,
    group   => $compose_user,
    mode    => '0644',
    content => template('profile/arr_stack/docker-compose.yml.erb'),
    require => File[$compose_dir],
    notify  => Exec['arr_stack_compose_up'],
  }

  # Recreate containers only when the compose file content changes.
  # Watchtower-driven container updates do not modify the compose file,
  # so this exec stays quiet during normal operation.
  exec { 'arr_stack_compose_up':
    command     => '/usr/bin/docker compose up -d',
    cwd         => $compose_dir,
    user        => $compose_user,
    refreshonly => true,
    logoutput   => true,
    require     => File["${compose_dir}/docker-compose.yml"],
  }
}
