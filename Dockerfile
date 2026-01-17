FROM alpine:3.20

# Install packages
RUN echo -e "https://dl-cdn.alpinelinux.org/alpine/edge/testing\nhttps://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
    apk update && \
    apk add --no-cache \
        cups cups-libs cups-pdf cups-client cups-filters cups-dev \
        ghostscript hplip avahi inotify-tools \
        python3 python3-dev build-base wget rsync \
        py3-pycups perl gcompat libc6-compat && \
    rm -rf /var/cache/apk/*

# Copy local Xerox deb and extract
COPY xerox-phaser-6000-6010_1.0-1_i386.deb /tmp/xerox.deb
RUN mkdir /tmp/xerox-extract && \
    cd /tmp/xerox-extract && \
    ar x /tmp/xerox.deb && \
    tar -xJf data.tar.xz && \
    cp -a usr/lib/cups/filter/* /usr/lib/cups/filter/ 2>/dev/null || true && \
    cp -a usr/share/cups/model/* /usr/share/cups/model/ 2>/dev/null || true && \
    cp -a usr/share/ppd/* /usr/share/ppd/ 2>/dev/null || true && \
    chmod 755 /usr/lib/cups/filter/X* 2>/dev/null || true && \
    cd / && \
    rm -rf /tmp/xerox.deb /tmp/xerox-extract && \
    true  # 成功保証

# Gutenprint (cups-genppdupdate用)
RUN apk add --no-cache --virtual=build-deps wget tar findutils sed make automake autoconf libtool && \
    wget -O /tmp/gutenprint-5.3.5.tar.xz "https://sourceforge.net/projects/gimp-print/files/gutenprint-5.3/5.3.5/gutenprint-5.3.5.tar.xz/download" && \
    tar -xJf /tmp/gutenprint-5.3.5.tar.xz -C /tmp && \
    cd /tmp/gutenprint-5.3.5 && \
    find src/testpattern -type f -exec sed -i 's/\bPAGESIZE\b/GPT_PAGESIZE/g' {} + && \
    ./configure && make -j$(nproc) && make install && \
    cd / && rm -rf /tmp/gutenprint* && \
    apk del build-deps && \
    sed -i '1s|.*|#!/usr/bin/perl|' /usr/sbin/cups-genppdupdate && \
    cups-genppdupdate

EXPOSE 631
VOLUME /config
VOLUME /services

ADD root /
RUN chmod +x /root/*

CMD ["/root/run_cups.sh"]

# Config (A4優先)
RUN sed -i 's/Listen localhost:631/Listen 0.0.0.0:631/' /etc/cups/cupsd.conf && \
    sed -i 's/Browsing Off/Browsing On/' /etc/cups/cupsd.conf && \
    sed -i 's/<Location \/>/<Location \/>\n  Allow All/' /etc/cups/cupsd.conf && \
    sed -i 's/<Location \/admin>/<Location \/admin>\n  Allow All/' /etc/cups/cupsd.conf && \
    sed -i 's/.*enable-dbus=.*/enable-dbus=no/' /etc/avahi/avahi-daemon.conf && \
    echo "ServerAlias *">> /etc/cups/cupsd.conf && \
    echo "DefaultPaperSize A4">> /etc/cups/cupsd.conf
