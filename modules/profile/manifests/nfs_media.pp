# profile::nfs_media
#
# Manages the NFS mount of the Synology PlexMediaServer share for use by
# Docker containers (Sonarr, Radarr, AudiobookShelf) that need read-write
# access to the media library.
#
# This is distinct from the separate NFS mount used by the Plex VM,
# which is also read-write (needed so Plex admin can delete media
# from within the app).
#
# Mount: 10.0.0.20:/volume1/PlexMediaServer -> /mnt/nas/plexmediaserver
class profile::nfs_media {

  # Ensure NFS client utilities are installed
  package { 'nfs-common':
    ensure => installed,
  }

  # Ensure the parent and target mountpoint directories exist
  file { '/mnt/nas':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/mnt/nas/plexmediaserver':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    require => File['/mnt/nas'],
  }

  # NFS mount with read-write access for the arr stack
  mount { '/mnt/nas/plexmediaserver':
    ensure  => mounted,
    device  => '10.0.0.20:/volume1/PlexMediaServer',
    fstype  => 'nfs',
    options => 'rw,defaults,_netdev,vers=3',
    atboot  => true,
    require => [
      Package['nfs-common'],
      File['/mnt/nas/plexmediaserver'],
    ],
  }
}
