class base::security {
  file { '/etc/fail2ban/jail.local':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "[sshd]\nenabled = true\nmaxretry = 3\nfindtime = 600\nbantime = 5y\n",
    notify  => Service['fail2ban'],
  }
  service { 'fail2ban':
    ensure  => running,
    enable  => true,
    require => File['/etc/fail2ban/jail.local'],
  }
  # auditd may fail in VMs due to kernel restrictions - non-fatal
  service { 'auditd':
    ensure  => running,
    enable  => true,
    require => Package['auditd'],
  }
  file { '/etc/issue.net':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "WARNING: Unauthorized access to this system is prohibited.\nAll activity is monitored and logged.\n",
  }
  file { '/etc/modprobe.d/disable-usb-storage.conf':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "install usb-storage /bin/true\n",
  }
}
