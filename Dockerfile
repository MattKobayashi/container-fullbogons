FROM alpine:3.22.1@sha256:4bcff63911fcb4448bd4fdacec207030997caf25e9bea4045fa6c8c44de311d1

RUN apk --no-cache add supercronic

# Set BIRD environment variables
ENV SOURCE_FILE=bird.tar.gz \
    SOURCE_URL=https://gitlab.nic.cz/labs/bird/-/archive/v2.16.1/bird-v2.16.1.tar.gz \
    SOURCE_SHA1SUM=cc6e5e7d0dcb05fafca48c38e2a46fd8a05dfaba

# Install BIRD
WORKDIR /bird
RUN apk --no-cache add tar build-base autoconf flex bison linux-headers ncurses-dev libssh-dev readline-dev \
    && wget -O "$SOURCE_FILE" "$SOURCE_URL" \
    && echo "${SOURCE_SHA1SUM}  ${SOURCE_FILE}" | sha1sum -c - \
    && tar -xz --strip-components=1 --file="$SOURCE_FILE" \
    && autoreconf \
    && ./configure \
    && make \
    && make install

# Post-install cleanup
RUN apk del tar build-base autoconf \
    && rm -rf /bird/*

# Copy external files
COPY requirements.txt .
COPY fullbogons.py .
COPY templates/* templates/
COPY crontab/* crontab/
COPY entrypoint.sh .

# Set up image for running BIRD
RUN adduser -D bird \
    && chown -R bird /bird/ \
    && apk --no-cache upgrade \
    && apk add py3-uv

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
