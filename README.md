# lucos_dns_secondary

DNS secondary server for the lucos estate. Runs BIND in `type secondary` mode, slaving all lucos-managed zones from the avalon primary (`178.32.218.44`) via TSIG-authenticated AXFR/IXFR.

## Managed zones

The following zones are hardcoded as secondaries:

- `l42.eu`
- `s.l42.eu`
- `lukeblaney.co.uk`
- `rowanblaney.co.uk`
- `tfluke.uk`

**Adding or removing a managed domain is a two-repo change:** the primary (`lucos_dns`) must be updated to author the zone and allow transfer, and this repo must be updated to slave it.

## Design

See [ADR-0010](https://github.com/lucas42/lucos/pull/215) for the architectural decision to model the secondary as its own repo rather than a mode of the primary image.

### Filesystem layout

- Zone files received via AXFR/IXFR are written to `/etc/bind/slave-zones/` inside the container, persisted via a Docker volume. This lets the secondary serve last-known-good zone data across restarts even if the primary is temporarily unreachable.
- There are no static authoritative zone files in the image — the secondary receives everything from the primary.

### TSIG authentication

Zone transfers are authenticated using a shared HMAC-SHA256 TSIG key (`lucos-tsig`). The key secret is injected at runtime via the `TSIG_SECRET` environment variable (managed by lucos_creds) and is never baked into the image.

## Deployment

Deployed to xwing on port 53 (TCP + UDP). See the lucos_configy entry for the full system definition.
