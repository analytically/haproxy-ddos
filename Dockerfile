FROM gliderlabs/alpine:3.2

ENV GOPATH /usr/share/gocode
ENV PATH $GOPATH/bin:$PATH

ADD captainhook.sh /etc/captainhook/

RUN apk add --update python && \
    apk add wget curl ca-certificates make g++ libgcc linux-headers openssl-dev git go supervisor bash && \
    wget "https://bootstrap.pypa.io/get-pip.py" -O /dev/stdout | python && \
    pip install envtpl && \
    pip install supervisor && \
    go get github.com/bketelsen/captainhook && \
    chmod u+x /etc/captainhook/captainhook.sh && \
    rm /var/cache/apk/*

# Set locale
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

# Disable python output buffering
ENV PYTHONUNBUFFERED 1

ADD supervisord.conf /etc/

RUN curl -sSf ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.39.tar.gz | tar xz \
    && cd pcre-8.39 \
    && CFLAGS="-O2 -march=x86-64" ./configure --prefix=/usr --docdir=/usr/share/doc/pcre-8.39 --enable-utf8 --enable-unicode-properties --enable-jit --disable-shared \
    && make \
    && make install \
    && cd .. \
    && rm -Rf pcre-8.39

RUN curl -sSf --retry 3 -L http://www.haproxy.org/download/1.5/src/haproxy-1.5.17.tar.gz | tar xz \
    && cd haproxy-1.5.17 \
    && make TARGET=linux2628 ARCH=x86_64 USE_ZLIB=1 USE_REGPARM=1 USE_STATIC_PCRE=1 USE_PCRE_JIT=1 USE_TFO=1 USE_OPENSSL=1 DEFINE="-fstack-protector -Wformat -Wformat-security -Werror=format-security -D_FORTIFY_SOURCE=2" \
    && make install \
    && cd .. \
    && rm -Rf haproxy-1.5.17

ADD captainhook /etc/captainhook/
ADD haproxy.sh /etc/haproxy-ddos/
ADD haproxy-restart.sh /etc/haproxy-ddos/
ADD haproxy.cfg.tpl /etc/haproxy-ddos/

ADD 403-html.http /etc/haproxy-ddos/errors/
ADD 403-json.http /etc/haproxy-ddos/errors/

ADD update-tor-exit-nodes.sh /etc/haproxy-ddos/

ADD blacklists /etc/haproxy-ddos/blacklists/
ADD whitelist.txt /etc/haproxy-ddos/

ADD supervisord.haproxy-ddos.conf /etc/supervisor/conf.d/

RUN chmod u+x /etc/haproxy-ddos/haproxy.sh \
    && chmod u+x /etc/haproxy-ddos/haproxy-restart.sh \
    && chmod u+x /etc/haproxy-ddos/update-tor-exit-nodes.sh

VOLUME ["/var/log", "/etc/ssl/private/"]
EXPOSE 666 667 668 669 670 671 672 673 674 675

# Run supervisord when starting container
CMD ["/usr/local/bin/supervisord", "-k", "-c", "/etc/supervisord.conf"]
