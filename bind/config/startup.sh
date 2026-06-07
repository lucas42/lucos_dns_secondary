#!/bin/sh
set -e

# Fail fast if TSIG_SECRET is missing — an empty secret creates a syntactically
# valid but non-functional config that would silently refuse all zone transfers.
if [ -z "${TSIG_SECRET}" ]; then
    echo "ERROR: TSIG_SECRET environment variable is not set" >&2
    exit 1
fi

# Ensure secondary-zones directory exists and is writable by the named runtime user.
# This directory is a volume mount — BIND writes received zone files here so the
# secondary can serve last-known-good zones across a restart even if the primary
# is temporarily unreachable.  Startup runs as root; named drops privileges after
# binding to port 53, so the directory must be owned by named before that happens.
mkdir -p /etc/bind/secondary-zones
chown named:named /etc/bind/secondary-zones

# Write the TSIG key file from the TSIG_SECRET environment variable.
# The secret is kept out of the image; it's injected at runtime via lucos_creds.
# Both the secondary and primary must use the same algorithm and secret value.
cat > /etc/bind/tsig.key << EOF
key "lucos-tsig" {
    algorithm hmac-sha256;
    secret "${TSIG_SECRET}";
};
EOF
chmod 640 /etc/bind/tsig.key
chown root:named /etc/bind/tsig.key

exec /usr/sbin/named -c /etc/bind/named.conf -g
