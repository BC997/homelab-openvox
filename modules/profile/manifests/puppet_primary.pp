# profile::puppet_primary
#
# Manages r10k on the primary. Intentionally unassigned in site.pp: deploys
# are run by hand so every change gets a noop review first. r10k pulls over
# SSH with a read only deploy key, so no token is stored anywhere.
class profile::puppet_primary (
  String $r10k_remote = 'ssh://git@gitea.lab.local:2222/OWNER/homelab-puppet.git',
  Integer $r10k_deploy_minute = 5,
) {
  # r10k config
  file { '/etc/puppetlabs/r10k':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0750',
  }
  file { '/etc/puppetlabs/r10k/r10k.yaml':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => template('profile/r10k.yaml.erb'),
    require => File['/etc/puppetlabs/r10k'],
  }
  # r10k cron
  cron { 'r10k-deploy':
    command => '/opt/puppetlabs/puppet/bin/r10k deploy environment production 2>&1 | logger -t r10k',
    user    => 'root',
    minute  => "*/${r10k_deploy_minute}",
    hour    => '*',
  }
  # Puppet server service
  service { 'puppetserver':
    ensure => running,
    enable => true,
  }
}
