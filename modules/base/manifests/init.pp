class base {
  include base::packages
  include base::ssh
  include base::security
  include base::dns
  include base::time
  include base::puppet_agent_config
  include base::puppetdb_conf
}
