# profile::puppet_primary is intentionally unassigned. r10k deploys are run
# by hand so every change gets a noop review before it goes live.

node 'openvox-cli.lab.local'   { include role::standard_server
                                 include profile::openvox_primary }

node 'plex-cli.lab.local'     { include role::media_server }

node 'cli-docker.lab.local'   { include role::standard_server
                                 include profile::docker
                                 include profile::prometheus_env
                                 include profile::pihole_env
                                 include profile::nfs_media
                                 include profile::arr_stack
                                 include profile::tautulli
                                 include profile::seerr }

node default                  { include role::standard_server }
