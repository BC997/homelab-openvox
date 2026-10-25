# profile::cloudflare_ddns
#
# Keeps the public example.com A records pointed at the home IP.
# Uses favonia/cloudflare-ddns (Apache 2.0). Records stay unproxied (grey cloud).
# Image tag 1 tracks the stable v1 line, so Watchtower never jumps a major version.
# Token comes from cli-docker eyaml and is Sensitive so it stays out of reports.
#
# Requires:
#   profile::docker - Docker Engine + compose plugin
class profile::cloudflare_ddns (
  String $api_token,
  String $domains      = 'ha.example.com,plex.example.com',
  String $image_tag    = '1',
  String $compose_user = 'ubuntu',
  String $compose_dir  = '/home/ubuntu/docker/cloudflare-ddns',
) {
  file { $compose_dir:
    ensure => directory,
    owner  => $compose_user,
    group  => $compose_user,
    mode   => '0755',
  }

  file { "${compose_dir}/.env":
    ensure  => file,
    owner   => $compose_user,
    group   => $compose_user,
    mode    => '0600',
    content => Sensitive("CLOUDFLARE_API_TOKEN=${api_token}\n"),
    require => File[$compose_dir],
    notify  => Exec['cloudflare_ddns_compose_up'],
  }

  file { "${compose_dir}/docker-compose.yml":
    ensure  => file,
    owner   => $compose_user,
    group   => $compose_user,
    mode    => '0644',
    content => template('profile/cloudflare_ddns/docker-compose.yml.erb'),
    require => File[$compose_dir],
    notify  => Exec['cloudflare_ddns_compose_up'],
  }

  exec { 'cloudflare_ddns_compose_up':
    command     => '/usr/bin/docker compose up -d',
    cwd         => $compose_dir,
    user        => $compose_user,
    refreshonly => true,
    logoutput   => true,
    require     => File["${compose_dir}/docker-compose.yml", "${compose_dir}/.env"],
  }
}
