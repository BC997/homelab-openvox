# Manages /etc/puppetlabs/puppet/puppet.conf so every agent has consistent
# configuration including PuppetDB integration (storeconfigs + reports).
class base::puppet_agent_config (
  String $server = 'openvox-cli.lab.local',
) {
  file { '/etc/puppetlabs/puppet/puppet.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('base/puppet.conf.erb'),
  }
}
