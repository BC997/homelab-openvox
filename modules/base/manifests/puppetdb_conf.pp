# Manages /etc/puppetlabs/puppet/puppetdb.conf so every agent points at
# PuppetDB's FQDN (not the short hostname) for SSL hostname verification.
class base::puppetdb_conf (
  String $server_urls = 'https://puppetdb.lab.local:8081',
) {
  file { '/etc/puppetlabs/puppet/puppetdb.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "# Managed by Puppet (base::puppetdb_conf) — DO NOT EDIT MANUALLY\n[main]\nserver_urls = ${server_urls}\nsoft_write_failure = true\n",
  }
}
