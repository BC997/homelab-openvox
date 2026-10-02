class profile::base (
  Boolean       $manage_nightly_reboot = true,
  Array[String] $firewall_extra_allow  = [],
  Array[String] $firewall_extra_ports  = [],
  Boolean       $manage_firewall       = true,
  String        $admin_user            = 'labadmin',
  String        $admin_password_hash   = '',
  String        $admin_ssh_key         = '',
) {
  include base
  include profile::node_exporter

  class { 'base::firewall':
    ensure              => $manage_firewall ? { true => 'enabled', false => 'disabled' },
    extra_allow_subnets => $firewall_extra_allow,
    extra_allow_ports   => $firewall_extra_ports,
  }
  # Ensure puppet agent daemon runs and survives reboots
  service { 'puppet':
    ensure => running,
    enable => true,
  }
  # Ensure the admin user exists on all nodes (name and key come from Hiera)
  user { $admin_user:
    ensure     => present,
    home       => "/home/${admin_user}",
    managehome => true,
    shell      => '/bin/bash',
    groups     => ['sudo'],
    password   => $admin_password_hash,
  }
  if $admin_ssh_key != '' {
    ssh_authorized_key { "${admin_user}@homelab":
      ensure  => present,
      user    => $admin_user,
      type    => 'ed25519',
      key     => $admin_ssh_key,
      require => User[$admin_user],
    }
  }
  file { "/etc/sudoers.d/${admin_user}-nopasswd":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0440',
    content => "${admin_user} ALL=(ALL) NOPASSWD: ALL\n",
    require => User[$admin_user],
  }
  # Weekly apt upgrade - Sunday 1AM
  cron { 'weekly-apt-upgrade':
    ensure  => present,
    command => '/usr/bin/apt-get update && /usr/bin/apt-get -y upgrade',
    user    => 'root',
    hour    => '1',
    minute  => '0',
    weekday => '0',
  }
  # Nightly reboot - 5AM (disabled on control-plane nodes via profile::base::manage_nightly_reboot: false)
  if $manage_nightly_reboot {
    cron { 'nightly-reboot':
      ensure  => present,
      command => '/sbin/reboot',
      user    => 'root',
      hour    => '5',
      minute  => '0',
    }
  } else {
    cron { 'nightly-reboot':
      ensure => absent,
      user   => 'root',
    }
  }
  # Ensure consistent timezone across all nodes - America/Los_Angeles
  exec { 'set-timezone':
    command => '/usr/bin/timedatectl set-timezone America/Los_Angeles',
    unless  => 'test "$(timedatectl show --property=Timezone --value)" = "America/Los_Angeles"',
    path    => ['/usr/bin', '/bin'],
  }
}
