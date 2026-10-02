# homelab-openvox

The configuration code behind my homelab. OpenVox 8 (the community fork of Open Source Puppet) manages every Ubuntu Server VM in the lab: base hardening, firewall, monitoring agents, Plex, and the Docker stacks on the main container host. r10k deploys this code from a self hosted Gitea repo.

This is a sanitized public copy of the internal repo. Architecture notes, runbooks, and lessons learned live in [homelab-docs](https://github.com/BC997/homelab-docs).

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

The Docker host adds service profiles in site.pp on top of its role.

**Hiera for everything that varies.** Firewall exceptions, ports, user and group IDs, paths, and agent server settings all come from Hiera. Encrypted values (eyaml) sit above plain values at each level, and per node data sits above common data.

**Idempotent execs.** Every exec is guarded with `creates`, `unless`, or `refreshonly`, so a clean run changes nothing. The ufw rules, the timezone, and the pinned fail2ban install all follow this pattern.

**Compose stacks rendered from templates.** Docker services are defined as ERB templates fed by Hiera. Containers are recreated only when the rendered compose file changes. Image updates are left to Watchtower, so normal Puppet runs stay quiet.

**Firewall by default.** `base::firewall` turns on ufw with default deny inbound, allows the LAN, and takes per node exceptions from Hiera. One example is letting Docker's bridge networks through on the container host so hairpin traffic is not dropped.

**Working around upstream bugs in code.** fail2ban 1.0.2 on Ubuntu 24.04 breaks under Python 3.12, so `base::packages` installs the upstream 1.1.0 package on noble and holds it.

**Explicit state removal.** When a feature is turned off in Hiera, the profile sets `ensure => absent` instead of just skipping the resource. Skipping would leave an already applied resource in place. The nightly reboot cron is the example here.

## Secrets

No secrets are in this repo. The internal repo keeps them in eyaml files encrypted with a PKCS7 keypair that never leaves the primary. Those files are excluded here, so parameters such as `pve_password`, `webpassword`, and `plex_token` show their empty defaults. The admin user name and SSH key are also Hiera parameters.

## Migration scripts

`docs/` holds the server side changes made when moving from Open Source Puppet to OpenVox. These cover settings that live outside Puppet managed paths on the primary: code directory, OpenVoxDB routes, autosign allowlist, and PuppetBoard patches. Codifying them into a profile is on the roadmap.

## Sanitization

IPs use a 10.0.0.0/24 placeholder range. The internal domain, credentials, keys, and some hosts are left out.
