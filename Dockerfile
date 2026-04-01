FROM debian:13.4

RUN apt update && apt install -y \
    curl \
    iproute2 \
    nftables \
    gnupg2 \
    desktop-file-utils \
    libcap2-bin \
    libnss3-tools \
    libpcap0.8 \
    sudo \
    supervisor \
    procps \
    lsb-release

COPY lib/gost_2.12.0_linux_amd64.tar.gz /tmp/gost.tar.gz

RUN tar -zxvf /tmp/gost.tar.gz -C /usr/local/bin/ \
    && chmod +x /usr/local/bin/gost \
    && rm /tmp/gost.tar.gz

# Add Cloudflare GPG key and repository
RUN curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list

COPY ./lib/cloudflare-warp_2026.1.150.0_amd64.deb /tmp/warp.deb

# Install cloudflare-warp from official repository
RUN apt update && dpkg -i /tmp/warp.deb

# Clean up package cache
RUN apt clean && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user for WARP registration  
# Use UID 1001 to avoid conflicts with existing users
RUN useradd -m -s /bin/bash -u 1001 warpuser

# Create a wrapper script to run WARP commands as warpuser
RUN echo '#!/bin/bash\n\
exec su -c "$*" warpuser\n\
' > /usr/local/bin/run-as-warpuser && chmod +x /usr/local/bin/run-as-warpuser

# Copy configuration files and scripts
COPY warp-setup.sh /usr/local/bin/warp-setup.sh
COPY gost_setup.sh /usr/local/bin/gost_setup.sh
RUN chmod +x /usr/local/bin/warp-setup.sh
RUN chmod +x /usr/local/bin/gost_setup.sh
COPY supervisord.conf /etc/supervisord.conf

# Create supervisor log directory
RUN mkdir -p /var/log/supervisor

# Expose SOCKS5/HTTP proxy port
EXPOSE 1080

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]