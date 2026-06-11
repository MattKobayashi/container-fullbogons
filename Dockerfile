FROM debian:13.5-slim@sha256:545a1665d9364d3b00d1c892aa8fabc88d3c1f1d673eeeedfa3051010ebd91bb
COPY --from=ghcr.io/astral-sh/uv:0.11.20@sha256:eaa5f1a3305307aaf9e67fe2bbba1d85ebbb2d8a63bce23af21797bfafbe0f8b /uv /uvx /bin/

RUN apt-get update \
    && apt-get install --no-install-recommends --yes \
    ca-certificates \
    curl \
    jq \
    zstd

# Supercronic
# renovate: datasource=github-releases packageName=aptible/supercronic
ARG SUPERCRONIC_VERSION="v0.2.46"
ARG SUPERCRONIC="supercronic-linux-amd64"
ARG SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/${SUPERCRONIC}
RUN export SUPERCRONIC_SHA256SUM=$(curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/repos/aptible/supercronic/releases \
    | jq -r '.[] | select(.name == $ENV.SUPERCRONIC_VERSION) | .assets[] | select(.name == $ENV.SUPERCRONIC) | .digest') \
    && echo "SHA256 digest from API: ${SUPERCRONIC_SHA256SUM}" \
    && curl -fsSLO "$SUPERCRONIC_URL" \
    && echo "${SUPERCRONIC_SHA256SUM}  ${SUPERCRONIC}" | sed -e 's/^sha256://' | sha256sum -c - \
    && chmod +x "$SUPERCRONIC" \
    && mv "$SUPERCRONIC" "/usr/local/bin/${SUPERCRONIC}" \
    && ln -s "/usr/local/bin/${SUPERCRONIC}" /usr/local/bin/supercronic

# renovate: datasource=github-tags packageName=CZ-NIC/bird
ARG BIRD_VERSION="v3.3.1"
ARG BIRD_URL=https://github.com/CZ-NIC/bird/archive/refs/tags/${BIRD_VERSION}.tar.gz

# Install BIRD
WORKDIR /bird
RUN apt-get install --no-install-recommends --yes build-essential autoconf flex bison git linux-headers-amd64 libncurses-dev libssh-dev libreadline-dev \
    && curl -fsSLo bird.tar.gz "$BIRD_URL" \
    && tar -xz --strip-components=1 --file="bird.tar.gz" \
    && autoreconf \
    && ./configure \
    && make \
    && make install

# Post-install cleanup
RUN apt-get remove --yes build-essential autoconf git jq zstd \
    && rm -rf /bird/*

# Copy external files
COPY fullbogons.py .
COPY templates/* templates/
COPY crontab/* crontab/
COPY entrypoint.sh .

# Set up image for running BIRD
RUN apt-get install --no-install-recommends --yes adduser \
    && adduser bird \
    && apt-get remove --yes adduser \
    && apt-get autoremove --yes \
    && apt-get clean \
    && chown -R bird /bird/

# Set expose ports
# BGP: 179/tcp
# RIP: 520/udp
# RIP-ng: 521/udp
EXPOSE 179/tcp 520/udp 521/udp

# Set default environment variables
ENV BIRD_ROUTER_ID= \
    BIRD_ASN=64666 \
    BIRD_PEERS= \
    BIRD_EXCLUDED_PREFIXES= \
    BIRD_DEBUG=states,filters,interfaces,events

# Set entrypoint
ENTRYPOINT ["./entrypoint.sh"]

LABEL org.opencontainers.image.authors="MattKobayashi <matthew@kobayashi.au>"
