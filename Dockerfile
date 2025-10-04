FROM debian:13.1-slim@sha256:1caf1c703c8f7e15dcf2e7769b35000c764e6f50e4d7401c355fb0248f3ddfdb
COPY --from=ghcr.io/astral-sh/uv:0.8.23@sha256:94390f20a83e2de83f63b2dadcca2efab2e6798f772edab52bf545696c86bdb4 /uv /uvx /bin/

RUN apt-get update \
    && apt-get install --no-install-recommends --yes ca-certificates curl zstd

# Latest releases available at https://github.com/aptible/supercronic/releases
ENV SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.2.36/supercronic-linux-amd64 \
    SUPERCRONIC_SHA1SUM=53a484404b0c559d64f78e9481a3ec22f782dc46 \
    SUPERCRONIC=supercronic-linux-amd64

RUN curl -fsSLO "$SUPERCRONIC_URL" \
    && echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c - \
    && chmod +x "$SUPERCRONIC" \
    && mv "$SUPERCRONIC" "/usr/local/bin/${SUPERCRONIC}" \
    && ln -s "/usr/local/bin/${SUPERCRONIC}" /usr/local/bin/supercronic

# Set BIRD environment variables
ENV SOURCE_FILE=bird-v3.0.4.tar.gz \
    SOURCE_URL=https://gitlab.nic.cz/labs/bird/-/archive/v3.0.4/bird-v3.0.4.tar.gz \
    SOURCE_SHA1SUM=28433b21a774b973665be5a18e39b9973449501a

# Install BIRD
WORKDIR /bird
RUN apt-get install --no-install-recommends --yes build-essential autoconf flex bison git linux-headers-amd64 libncurses-dev libssh-dev libreadline-dev \
    && curl -fsSLO "$SOURCE_URL" \
    && echo "${SOURCE_SHA1SUM}  ${SOURCE_FILE}" | sha1sum -c - \
    && tar -xz --strip-components=1 --file="$SOURCE_FILE" \
    && autoreconf \
    && ./configure \
    && make \
    && make install

# Post-install cleanup
RUN apt-get remove --yes build-essential autoconf git zstd \
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
