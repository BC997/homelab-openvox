# base::time
#
# Ubuntu's built in systemd-timesyncd keeps every node's clock in sync.
# This makes sure it stays enabled and running. Chrony was considered and
# not needed: timesyncd holds sub millisecond offsets on this fleet.
class base::time {
  service { 'systemd-timesyncd':
    ensure => running,
    enable => true,
  }
}
