#!/bin/bash
# PuppetBoard fixes for OpenVox — required after fresh install or package upgrade
# Documented Aug 18-19, 2026 during OpenVox migration
set -e

echo "=== Fix 1: routes.yaml — enable facts+catalog submission to OpenVoxDB ==="
sudo tee /etc/puppetlabs/puppet/routes.yaml > /dev/null << 'EOF'
master:
  facts:
    terminus: puppetdb
    cache: yaml
EOF

echo "=== Fix 2: auth.conf — allow unauthenticated access to PuppetDB metrics endpoint ==="
sudo sed -i 's/allow: "\*"/allow-unauthenticated: true/' /etc/puppetlabs/puppetdb/conf.d/auth.conf

echo "=== Fix 3: index.py — graceful fallback when metrics endpoint fails ==="
INDEX_PY="/opt/puppetboard/venv/lib/python3.12/site-packages/puppetboard/views/index.py"
sudo python3 << PYEOF
path = "$INDEX_PY"
with open(path) as f:
    content = f.read()
old = '''        num_nodes = get_or_abort(puppetdb.metric, f"{prefix}:name=num-nodes")
        num_resources = get_or_abort(puppetdb.metric, f"{prefix}:name=num-resources")
        metrics['num_nodes'] = num_nodes['Value']
        metrics['num_resources'] = num_resources['Value']'''
new = '''        try:
            num_nodes = puppetdb.metric(f"{prefix}:name=num-nodes")
        except Exception:
            num_nodes = {'Value': 0}
        try:
            num_resources = puppetdb.metric(f"{prefix}:name=num-resources")
        except Exception:
            num_resources = {'Value': 0}
        metrics['num_nodes'] = num_nodes['Value']
        metrics['num_resources'] = num_resources['Value']'''
if old in content:
    content = content.replace(old, new)
    with open(path, 'w') as f:
        f.write(content)
    print("index.py patched")
else:
    print("WARNING: index.py pattern not found - manual patch needed")
PYEOF

echo "=== Fix 4: dailychart.py — fix UTC/PDT timezone boundary bug ==="
sudo sed -i "s/today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0, tzinfo=UTC())/today = datetime.now(UTC()).replace(hour=0, minute=0, second=0, microsecond=0)/" /opt/puppetboard/venv/lib/python3.12/site-packages/puppetboard/views/dailychart.py

echo "=== Restarting services ==="
sudo systemctl restart puppetserver
sleep 30
sudo systemctl restart puppetdb
sleep 10
sudo systemctl stop puppetboard && sleep 2 && sudo systemctl start puppetboard

echo "=== Done. Verify at http://$(hostname -I | awk '{print $1}'):8000 ==="
