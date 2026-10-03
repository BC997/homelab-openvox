# profile::openvox_primary
#
# Keeps the hand applied OpenVox, OpenVoxDB and PuppetBoard fixes in place on
# the primary. If a package upgrade or rebuild undoes one, the next agent run
# puts it back and restarts the service that needs it.
#
# Not managed here: server-code-dir in puppetserver.conf. If that setting is
# lost, the server cannot load this code at all, so Puppet could never repair
# it. It stays documented in docs/openvox-master-setup.sh.
class profile::openvox_primary (
  Array[String[1], 1] $autosign_certnames,
  String $puppetboard_dir = '/opt/puppetboard/venv/lib/python3.12/site-packages/puppetboard',
) {
  $fixes = '/usr/local/sbin/openvox-primary-fixes'

  service { ['puppetserver', 'puppetdb', 'puppetboard']:
    ensure => running,
    enable => true,
  }

  # Send facts and catalogs to OpenVoxDB
  file { '/etc/puppetlabs/puppet/routes.yaml':
    ensure  => file,
    content => "master:\n  facts:\n    terminus: puppetdb\n    cache: yaml\n",
    notify  => Service['puppetserver'],
  }

  # Explicit autosign allowlist from Hiera, never a wildcard
  $autosign_list = join($autosign_certnames, "\n")
  file { '/etc/puppetlabs/puppet/autosign.conf':
    ensure  => file,
    content => "${autosign_list}\n",
  }

  file { $fixes:
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/profile/openvox_primary/openvox-primary-fixes',
  }

  exec { 'openvox-fix-puppetdb-auth':
    command => "${fixes} puppetdb-auth apply",
    onlyif  => "${fixes} puppetdb-auth check",
    require => File[$fixes],
    notify  => Service['puppetdb'],
  }

  exec { 'openvox-fix-puppetboard-index':
    command => "${fixes} puppetboard-index apply ${puppetboard_dir}",
    onlyif  => "${fixes} puppetboard-index check ${puppetboard_dir}",
    require => File[$fixes],
    notify  => Service['puppetboard'],
  }

  exec { 'openvox-fix-puppetboard-dailychart':
    command => "${fixes} puppetboard-dailychart apply ${puppetboard_dir}",
    onlyif  => "${fixes} puppetboard-dailychart check ${puppetboard_dir}",
    require => File[$fixes],
    notify  => Service['puppetboard'],
  }
}
