node 'openvox-cli.lab.local'   { include role::standard_server }

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
