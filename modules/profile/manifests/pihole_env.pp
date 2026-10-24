class profile::pihole_env (
  String $tz               = 'America/Los_Angeles',
  String $webpassword      = '',
  String $ftl_webserver_port = '8080',
) {
  file { '/home/ubuntu/docker/pihole/.env':
    ensure  => present,
    owner   => 'ubuntu',
    group   => 'ubuntu',
    mode    => '0640',
    content => "TZ=${tz}\nWEBPASSWORD=${webpassword}\nFTLCONF_webserver_port=${ftl_webserver_port}\n",
  }
}
