FROM alpine:3.20

# Repositories + Packages
RUN echo -e "https://dl-cdn.alpinelinux.org/alpine/edge/testing\nhttps://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
    apk update && \
    apk add --no-cache \
        cups cups-libs cups-pdf cups-client cups-filters cups-dev \
        ghostscript hplip avahi inotify-tools \
        python3 python3-dev build-base wget rsync tar findutils sed make automake autoconf libtool \
        py3-pycups perl gcompat libc6-compat musl-locales musl-locales-lang font-noto-cjk && \
    rm -rf /var/cache/apk/*

# Japanese locale
RUN echo "ja_JP.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen ja_JP.UTF-8 && \
    update-locale LANG=ja_JP.UTF-8 LC_ALL=ja_JP.UTF-8
ENV LANG=ja_JP.UTF-8 LANGUAGE=ja_JP:ja LC_ALL=ja_JP.UTF-8

# Copy & Extract local Xerox deb
COPY xerox-phaser-6000-6010_1.0-1_i386.deb /tmp/xerox.deb
RUN mkdir /tmp/xerox-extract && cd /tmp/xerox-extract && \
    ar x /tmp/xerox.deb && \
    tar xf data.tar.xz && \
    cp -a usr/lib/cups/filter/* /usr/lib/cups/filter/ 2>/dev/null || true && \
    cp -a usr/share/cups/model/* /usr/share/cups/model/ 2>/dev/null || true && \
    cp -a usr/share/ppd/* /usr/share/ppd/ 2>/dev/null || true && \
    chmod 755 /usr/lib/cups/filter/*XRM* 2>/dev/null || true && \
    cd / && rm -rf /tmp/xerox* /tmp/xerox-extract && \
    true

# Gutenprint for PPD generation
RUN wget -O /tmp/gutenprint.tar.xz "https://sourceforge.net/projects/gimp-print/files/gutenprint-5.3/5.3.5/gutenprint-5.3.5.tar.xz/download" && \
    tar -xJf /tmp/gutenprint.tar.xz -C /tmp && \
    cd /tmp/gutenprint-5.3.5 && \
    find src/testpattern -type f -exec sed -i 's/\bPAGESIZE\b/GPT_PAGESIZE/g' {} + && \
    ./configure && make -j$(nproc) && make install && \
    cd / && rm -rf /tmp/gutenprint* && \
    sed -i '1s|.*|#!/usr/bin/perl|' /usr/sbin/cups-genppdupdate

# Force Xerox PPD registration
RUN find /usr/share -name "*phaser*6000*.ppd*" -o -name "*Xerox*6000*.ppd*" | xargs -I {} cp {} /usr/share/cups/model/ 2>/dev/null || true && \
    /usr/sbin/cups-genppdupdate

EXPOSE 631
VOLUME ["/config", "/services"]

# Scripts (assuming original repo structure)
COPY root/ /root/
RUN chmod +x /root/*

CMD ["/root/run_cups.sh"]

# CUPS config (日本語・A4対応)
RUN sed -i 's/Listen localhost:631/Listen 0.0.0.0:631/' /etc/cups/cupsd.conf && \
    sed -i 's/Browsing Off/Browsing On/' /etc/cups/cupsd.conf && \
    sed -i 's/IdleExitTimeout/#IdleExitTimeout/' /etc/cups/cupsd.conf && \
    sed -i 's/<Location \/>/<Location \/>\n  Allow All/' /etc/cups/cupsd.conf && \
    sed -i 's/<Location \/admin>/<Location \/admin>\n  Allow All\n  Require user @SYSTEM/' /etc/cups/cupsd.conf && \
    sed -i 's/<Location \/admin\/conf>/<Location \/admin\/conf>\n  Allow All/' /etc/cups/cupsd.conf && \
    sed -i 's/.*enable-dbus=.*/enable-dbus=no/' /etc/avahi/avahi-daemon.conf && \
    echo "ServerAlias *">>/etc/cups/cupsd.conf && \
    echo "DefaultEncryption Never">>/etc/cups/cupsd.conf && \
    echo "DefaultPaperSize A4">>/etc/cups/cupsd.conf && \
    echo "ReadyPaperSizes A4 Letter">>/etc/cups/cupsd.conf && \
    echo "pdftops-renderer ghostscript">>/etc/cups/cupsd.conf
