FROM alpine:3.20

# Install the packages we need. Avahi will be included
RUN echo -e "https://dl-cdn.alpinelinux.org/alpine/edge/testing\nhttps://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories &&\
	apk add --update --no-cache cups \
	cups-libs \
	cups-pdf \
	cups-client \
	cups-filters \
	cups-dev \
	ghostscript \
	hplip \
	avahi \
	inotify-tools \
	python3 \
	python3-dev \
	build-base \
	wget \
	rsync \
	py3-pycups \
	perl \
	gcompat \
	libc6-i386 \
	lib32-gcc-libs \
	&& rm -rf /var/cache/apk/*

# Install Xerox Phaser 6000/6010 driver (for MultiWriter 5600C) - i386 deb extraction
RUN wget https://download.support.xerox.com/pub/drivers/6000/drivers/linux/xerox-phaser-6000-6010_1.0-2_i386.deb && \
    ar x xerox-phaser-6000-6010_1.0-2_i386.deb && \
    tar -xJf data.tar.xz && \
    cp -a usr/lib/cups/filter/* /usr/lib/cups/filter/ && \
    cp -a usr/share/cups/model/* /usr/share/cups/model/ && \
    cp -a usr/share/ppd/* /usr/share/ppd/ || true && \
    chmod +x /usr/lib/cups/filter/X* && \
    /usr/sbin/cups-genppdupdate && \
    rm -rf xerox-phaser-6000-6010_1.0-2_i386.deb data.tar.xz usr && \
    ldconfig /usr/lib /usr/lib32 2>/dev/null || true

# Build and install brlaser from source (keep original)
RUN apk add --no-cache git cmake && \
    git clone https://github.com/pdewacht/brlaser.git && \
    cd brlaser && \
    cmake . && \
    make && \
    make install && \
    cd .. && \
    rm -rf brlaser && \
    apk del git cmake

# Build and install gutenprint from source (keep original)
RUN wget -O gutenprint-5.3.5.tar.xz https://sourceforge.net/projects/gimp-print/files/gutenprint-5.3/5.3.5/gutenprint-5.3.5.tar.xz/download && \
    tar -xJf gutenprint-5.3.5.tar.xz && \
    cd gutenprint-5.3.5 && \
    find src/testpattern -type f -exec sed -i 's/\bPAGESIZE\b/GPT_PAGESIZE/g' {} + && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf gutenprint-5.3.5 gutenprint-5.3.5.tar.xz && \
    sed -i '1s|.*|#!/usr/bin/perl|' /usr/sbin/cups-genppdupdate

# This will use port 631
EXPOSE 631

# We want a mount for these
VOLUME /config
VOLUME /services

# Add scripts
ADD root /
RUN chmod +x /root/*

#Run Script
CMD ["/root/run_cups.sh"]

# Baked-in config file changes (keep original)
RUN sed -i 's/Listen localhost:631/Listen 0.0.0.0:631/' /etc/cups/cupsd.conf && \
	sed -i 's/Browsing Off/Browsing On/' /etc/cups/cupsd.conf && \
 	sed -i 's/IdleExitTimeout/#IdleExitTimeout/' /etc/cups/cupsd.conf && \
	sed -i 's/<Location \/>/<Location \/>\n  Allow All/' /etc/cups/cupsd.conf && \
	sed -i 's/<Location \/admin>/<Location \/admin>\n  Allow All\n  Require user @SYSTEM/' /etc/cups/cupsd.conf && \
	sed -i 's/<Location \/admin\/conf>/<Location \/admin\/conf>\n  Allow All/' /etc/cups/cupsd.conf && \
	sed -i 's/.*enable\-dbus=.*/enable\-dbus\=no/' /etc/avahi/avahi-daemon.conf && \
	echo "ServerAlias *" >> /etc/cups/cupsd.conf && \
	echo "DefaultEncryption Never" >> /etc/cups/cupsd.conf && \
	echo "ReadyPaperSizes A4,TA4,4X6FULL,T4X6FULL,2L,T2L,A6,A5,B5,L,TL,INDEX5,8x10,T8x10,4X7,T4X7,Postcard,TPostcard,ENV10,EnvDL,ENVC6,Letter,Legal" >> /etc/cups/cupsd.conf && \
	echo "DefaultPaperSize A4" >> /etc/cups/cupsd.conf && \
	echo "pdftops-renderer ghostscript" >> /etc/cups/cupsd.conf
