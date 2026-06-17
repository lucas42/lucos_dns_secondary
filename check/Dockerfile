FROM alpine:3.24.1

# Install supercronic v0.2.46 — a container-native cron runner that propagates the
# container environment to jobs natively, logs stdout/stderr to docker logs, and
# uses standard crontab syntax.
# Update the version string and sha1sums for the corresponding release when upgrading.
# Latest releases: https://github.com/aptible/supercronic/releases
ARG TARGETARCH
RUN set -e; \
    case "$TARGETARCH" in \
        amd64) sha1sum="5bcefed628e32adc08e32634db2d10e9230dbca0" ;; \
        arm64) sha1sum="639ab81a72771990790df7ee87d9acfe88e5fa83" ;; \
        *) echo "Unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    wget -qO /usr/local/bin/supercronic \
        "https://github.com/aptible/supercronic/releases/download/v0.2.46/supercronic-linux-${TARGETARCH}"; \
    echo "${sha1sum}  /usr/local/bin/supercronic" | sha1sum -c -; \
    chmod +x /usr/local/bin/supercronic

RUN apk --update add bind-tools curl

# VERSION must come after expensive layers above so a new deploy tag does not
# bust the supercronic/apk cache.
ARG VERSION
ENV VERSION=$VERSION

# Build context is the repo root (see docker-compose.yml) so this image can copy
# bind/config/named.conf.local — the single source of truth for the served-zone
# list — from the same file the bind image uses. check.sh derives its zone list
# from this at runtime, eliminating the hardcoded-list drift.
WORKDIR /app
COPY check/check.sh .
COPY check/crontab /crontab
COPY bind/config/named.conf.local ./named.conf.local
RUN chmod +x check.sh

CMD ["supercronic", "/crontab"]
