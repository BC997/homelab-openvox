class base::packages {
  $common_packages = [
    'curl',
    'wget',
    'vim',
    'htop',
    'git',
    'net-tools',
    'unzip',
    'ca-certificates',
    'ufw',
    'auditd',
    'libpam-pwquality',
    'openssh-server',
    'openssh-client',
    'libaudit1',
    'libaudit-common',
    'qemu-guest-agent',
  ]

  package { $common_packages:
    ensure => installed,
  }

  # fail2ban 1.0.2 in Ubuntu 24.04 is broken with Python 3.12
  # Install upstream 1.1.0 deb instead and hold the package
  if $facts['os']['distro']['codename'] == 'noble' {
    package { 'python3-setuptools':
      ensure => installed,
    }
    file { '/var/cache/puppet':
      ensure => directory,
    }
    exec { 'download-fail2ban':
      command => '/usr/bin/wget -q https://github.com/fail2ban/fail2ban/releases/download/1.1.0/fail2ban_1.1.0-1.upstream1_all.deb -O /var/cache/puppet/fail2ban_1.1.0.deb',
      creates => '/var/cache/puppet/fail2ban_1.1.0.deb',
      require => File['/var/cache/puppet'],
    }
    exec { 'install-fail2ban':
      command => '/usr/bin/dpkg -i /var/cache/puppet/fail2ban_1.1.0.deb',
      unless  => '/usr/bin/dpkg -l fail2ban | /bin/grep -q 1.1.0',
      require => [Exec['download-fail2ban'], Package['python3-setuptools']],
    }
    exec { 'hold-fail2ban':
      command => '/usr/bin/apt-mark hold fail2ban',
      unless  => '/usr/bin/apt-mark showhold | /bin/grep -q fail2ban',
      require => Exec['install-fail2ban'],
    }
  } else {
    package { 'fail2ban':
      ensure => installed,
    }
  }
}
