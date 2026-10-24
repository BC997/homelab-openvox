# base::firewall
#
# Enables ufw on managed nodes, default-deny incoming, allow all
# traffic from the trusted LAN subnet. A node can opt out via
# ensure => 'disabled' when another component owns its firewall.
#
# extra_allow_subnets: additional CIDR ranges to allow inbound from
# on ALL ports. Used e.g. on Docker hosts to permit hairpin NAT
# traffic from Docker's internal bridge networks (172.16.0.0/12),
# which would otherwise appear to ufw as non-LAN-sourced and get
# blocked.
#
# extra_allow_ports: specific ports to allow inbound from ANY
# source, regardless of lan_subnet. Used e.g. for services that
# intentionally need public reachability (Plex on 32400), while
# everything else on the host stays LAN-only.
class base::firewall (
  Enum['enabled', 'disabled'] $ensure              = 'enabled',
  String                      $lan_subnet           = '10.0.0.0/24',
  Array[String]                $extra_allow_subnets = [],
  Array[String]                $extra_allow_ports   = [],
) {
  if $ensure == 'enabled' {
    exec { 'ufw-default-deny-incoming':
      command => '/usr/sbin/ufw default deny incoming',
      unless  => '/usr/sbin/ufw status verbose | /bin/grep -q "Default: deny (incoming)"',
      require => Package['ufw'],
    }
    exec { 'ufw-default-allow-outgoing':
      command => '/usr/sbin/ufw default allow outgoing',
      unless  => '/usr/sbin/ufw status verbose | /bin/grep -q "allow (outgoing)"',
      require => Package['ufw'],
    }
    exec { 'ufw-allow-lan':
      command => "/usr/sbin/ufw allow from ${lan_subnet}",
      unless  => "/usr/sbin/ufw status | /bin/grep -q '${lan_subnet}'",
      require => [Exec['ufw-default-deny-incoming'], Exec['ufw-default-allow-outgoing']],
    }
    $extra_allow_subnets.each |String $subnet| {
      exec { "ufw-allow-${subnet}":
        command => "/usr/sbin/ufw allow from ${subnet}",
        unless  => "/usr/sbin/ufw status | /bin/grep -q '${subnet}'",
        require => [Exec['ufw-default-deny-incoming'], Exec['ufw-default-allow-outgoing']],
      }
    }
    $extra_allow_ports.each |String $port| {
      exec { "ufw-allow-port-${port}":
        command => "/usr/sbin/ufw allow ${port}",
        unless  => "/usr/sbin/ufw status | /bin/grep -qE '^${port}[/[:space:]].*ALLOW.*Anywhere'",
        require => [Exec['ufw-default-deny-incoming'], Exec['ufw-default-allow-outgoing']],
      }
    }
    exec { 'ufw-enable':
      command => '/usr/sbin/ufw --force enable',
      unless  => '/usr/sbin/ufw status | /bin/grep -q "Status: active"',
      require => Exec['ufw-allow-lan'],
    }
  } else {
    exec { 'ufw-disable':
      command => '/usr/sbin/ufw --force disable',
      unless  => '/usr/sbin/ufw status | /bin/grep -q "Status: inactive"',
      require => Package['ufw'],
    }
  }
}
