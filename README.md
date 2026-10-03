# homelab-openvox

The configuration code behind my homelab. OpenVox 8 (the community fork of Open Source Puppet) manages every Ubuntu Server VM in the lab: base hardening, firewall, monitoring agents, Plex, and the Docker stacks on the main container host. r10k deploys this code from a self hosted Gitea repo.

This is a sanitized public copy of the internal repo. Architecture notes, runbooks, and lessons learned live in [homelab-docs](https://github.com/BC997/homelab-docs).

## Start here

| File | Why it is worth a look |
|---|---|
| [manifests/site.pp](manifests/site.pp) | How each VM is classified |
| [modules/profile/manifests/openvox_primary.pp](modules/profile/manifests/openvox_primary.pp) | Self healing server fixes on the primary, with a check and apply helper script |
| [modules/profile/manifests/base.pp](modules/profile/manifests/base.pp) | Fleet baseline, Hiera driven admin user, explicit absent branch |
| [modules/base/manifests/firewall.pp](modules/base/manifests/firewall.pp) | ufw with default deny and per node exceptions, all idempotent |
| [modules/base/manifests/packages.pp](modules/base/manifests/packages.pp) | Pinned fail2ban workaround for Ubuntu 24.04 |
| [modules/profile/manifests/arr_stack.pp](modules/profile/manifests/arr_stack.pp) | Compose stack rendered from a template, recreated only on change |
| [modules/profile/manifests/plex.pp](modules/profile/manifests/plex.pp) | Package, repo, upgrade cron, and systemd override driven by Hiera |
| [hiera.yaml](hiera.yaml) | Lookup order with encrypted data above plain data |
| [docs/openvox-master-setup.sh](docs/openvox-master-setup.sh) | Bootstrap for a fresh primary, before Puppet takes over |

## Layout

    manifests/site.pp            Node classification
    hiera.yaml                   Hiera hierarchy (eyaml over yaml, per node over common)
    data/                        Hiera data (plain values only, see below)
    modules/base/                Fleet baseline: packages, SSH, fail2ban, auditd, ufw, DNS, agent config
    modules/profile/             One profile per service or concern
    modules/role/                Roles that compose profiles
    docs/                        Server side setup that lives outside Puppet managed paths

## Design

**Roles and profiles.** Every node gets one role. Roles only include profiles. Profiles hold the resources. Node specific differences live in Hiera, not in code.

| Role | Profiles |
|---|---|
| role::standard_server | profile::base |
| role::media_server | profile::base, profile::plex |

The Docker host adds service profiles in site.pp on top of its role, and the primary adds `profile::openvox_primary`.

**Hiera for everything that varies.** Firewall exceptions, ports, user and group IDs, paths, and agent server settings all come from Hiera. Encrypted values (eyaml) sit above plain values at each level, and per node data sits above common data.

**Idempotent execs.** Every exec is guarded with `creates`, `unless`, or `refreshonly`, so a clean run changes nothing. The ufw rules, the timezone, and the pinned fail2ban install all follow this pattern.

**Compose stacks rendered from templates.** Docker services are defined as ERB templates fed by Hiera. Containers are recreated only when the rendered compose file changes. Image updates are left to Watchtower, so normal Puppet runs stay quiet.

**Firewall by default.** `base::firewall` turns on ufw with default deny inbound, allows the LAN, and takes per node exceptions from Hiera. One example is letting Docker's bridge networks through on the container host so hairpin traffic is not dropped.

**Working around upstream bugs in code.** fail2ban 1.0.2 on Ubuntu 24.04 breaks under Python 3.12, so `base::packages` installs the upstream 1.1.0 package on noble and holds it.

**Self healing server fixes.** The primary needs a few settings that live outside normal Puppet paths: OpenVoxDB routes, a metrics access rule, the autosign allowlist, and two PuppetBoard code patches. `profile::openvox_primary` enforces all of them. A small helper script has a `check` mode and an `apply` mode for each fix, and Puppet only runs `apply` when `check` reports the fix is missing. If a package upgrade undoes one, the next agent run puts it back and restarts only the affected service. If an upgrade changes the code a patch expects, `apply` fails loudly instead of guessing, so the run shows as failed in PuppetBoard. This was tested by undoing a fix by hand and watching the next run repair it.

**Enforcing what already works.** `base::time` keeps Ubuntu's built in `systemd-timesyncd` enabled and running on every node. Chrony was evaluated and dropped, since timesyncd already holds sub millisecond offsets.

**Explicit state removal.** When a feature is turned off in Hiera, the profile sets `ensure => absent` instead of just skipping the resource. Skipping would leave an already applied resource in place. The nightly reboot cron is the example here.

## Secrets

No secrets are in this repo. The internal repo keeps them in eyaml files encrypted with a PKCS7 keypair that never leaves the primary. Those files are excluded here, so parameters such as `pve_password`, `webpassword`, and `plex_token` show their empty defaults. The admin user name and SSH key are also Hiera parameters.

No access tokens are used either. r10k pulls with a read only SSH deploy key scoped to this one repo, and edits are pushed with a separate SSH key. Before the old token was revoked, every place that used it was found and moved first, so nothing broke.

## Bootstrap scripts

`docs/` holds the server side changes made when moving from Open Source Puppet to OpenVox. `profile::openvox_primary` now enforces almost all of them, so the scripts are only needed to bring up a fresh primary before its first agent run. The one setting Puppet cannot own is `server-code-dir`: if it is wrong, the server cannot load any code, including the profile that would fix it.

## Sanitization

IPs use a 10.0.0.0/24 placeholder range. The internal domain, credentials, keys, and some hosts are left out.
