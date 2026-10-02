#!/bin/bash
# OpenVox master-level configuration — NOT Puppet-managed, lives on the
# filesystem of openvox-cli.lab.local directly. Required after fresh
# install or VM rebuild. Documented Aug 18-19, 2026 during OpenVox migration.
set -e

echo "=== puppetserver.conf: codedir must match homelab convention ==="
echo "File: /etc/puppetlabs/puppetserver/conf.d/puppetserver.conf"
echo "Ensure: server-code-dir: /etc/puppet/code  (NOT the /etc/puppetlabs/code default)"
echo "(manual edit required - this is a HOCON config file, not safely sed-able)"

echo "=== puppet.conf [server] codedir must also match ==="
sudo /opt/puppetlabs/bin/puppet config set codedir /etc/puppet/code --section server

echo "=== routes.yaml: enable facts+catalog submission to OpenVoxDB ==="
sudo tee /etc/puppetlabs/puppet/routes.yaml > /dev/null << 'EOF'
master:
  facts:
    terminus: puppetdb
    cache: yaml
EOF

echo "=== autosign.conf: explicit allowlist, NOT a wildcard ==="
sudo tee /etc/puppetlabs/puppet/autosign.conf > /dev/null << 'EOF'
openvox-cli.lab.local
plex-cli.lab.local
cli-docker.lab.local
EOF

echo "=== PuppetDB auth.conf: allow unauthenticated access to metrics endpoint ==="
sudo sed -i 's/allow: "\*"/allow-unauthenticated: true/' /etc/puppetlabs/puppetdb/conf.d/auth.conf

echo "=== PuppetDB database.ini: point at local Postgres ==="
echo "File: /etc/puppetlabs/puppetdb/conf.d/database.ini"
echo "Requires: local puppetdb Postgres role/database created (see puppetdb-ssl-setup notes)"
echo "subname = //localhost:5432/puppetdb"
echo "username and password: set when the Postgres role is created (never stored in git)"

echo "=== Restart services to apply ==="
sudo systemctl restart puppetserver
sleep 30
sudo systemctl restart puppetdb
sleep 10

echo "=== See also: docs/puppetboard-fixes.sh for PuppetBoard-specific patches ==="
