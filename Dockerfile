FROM ubuntu:20.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    git \
    net-tools \
    cmake \
    make \
    gcc \
    python3 \
    python3-pip \
    iptables \
    && rm -rf /var/lib/apt/lists/*

# Install BadVPN
WORKDIR /usr/src
RUN wget https://github.com/ambrop72/badvpn/archive/refs/tags/1.999.130.tar.gz \
    && tar xf 1.999.130.tar.gz \
    && cd badvpn-1.999.130 \
    && cmake -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 \
    && make install

# Create necessary directories
RUN mkdir -p /etc/udp /var/log/udp-custom

# Copy configuration files
COPY config/config.json /etc/udp/
COPY config/udp-custom.service /etc/systemd/system/
COPY config/udpgw.service /etc/systemd/system/
COPY module/limiter.sh /usr/local/bin/
COPY module/udp /usr/local/bin/
COPY bin/udp-custom-linux-amd64 /usr/local/bin/udp-custom

# Set permissions
RUN chmod +x /usr/local/bin/udp-custom \
    && chmod +x /usr/local/bin/limiter.sh \
    && chmod +x /usr/local/bin/udp

# Expose ports
EXPOSE 36712/tcp 7300/udp 7100/udp 7200/udp

# Copy entrypoint script
COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"] 