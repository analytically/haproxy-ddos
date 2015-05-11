FROM ubuntu:14.04.2

ENV GOPATH /usr/share/gocode
ENV PATH $GOPATH/bin:$PATH

ADD captainhook.sh /etc/captainhook/

RUN locale-gen --no-purge en_US.UTF-8 \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get upgrade -qy \
    && dpkg-divert --local --rename --add /sbin/initctl \
    && ln -sf /bin/true /sbin/initctl \
    && DEBIAN_FRONTEND=noninteractive apt-get install -qy build-essential libcurl4-gnutls-dev libreadline-dev e2fslibs-dev libssl-dev libsqlite3-dev sqlite3 libyaml-dev libxml2-dev libxslt1-dev python-dev python-support zlib1g-dev \
    && DEBIAN_FRONTEND=noninteractive apt-get install -qy ca-certificates apt-transport-https curl psmisc software-properties-common git golang-go openssl socat sysstat dos2unix \
    && curl -o - https://bootstrap.pypa.io/get-pip.py | python2.7 \
    && pip install envtpl \
    && pip install supervisor \
    && go get github.com/bketelsen/captainhook \
    && chmod u+x /etc/captainhook/captainhook.sh

# Set locale
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Disable python output buffering
ENV PYTHONUNBUFFERED 1

ADD .bashrc /root/
ADD supervisord.conf /etc/

RUN curl -sSf ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.37.tar.gz | tar xz \
    && cd pcre-8.37 \
    && CFLAGS="-O2 -march=x86-64" ./configure --prefix=/usr --docdir=/usr/share/doc/pcre-8.37 --enable-utf8 --enable-unicode-properties --enable-jit --disable-shared \
    && make \
    && make install \
    && cd .. \
    && rm -Rf pcre-8.37

RUN DEBIAN_FRONTEND=noninteractive apt-get install -qy --no-install-recommends iptables \
    && curl -sSf --retry 3 -L http://www.haproxy.org/download/1.5/src/haproxy-1.5.12.tar.gz | tar xz \
    && cd haproxy-1.5.12 \
    && make clean \
    && make TARGET=linux2628 ARCH=x86_64 USE_ZLIB=1 USE_REGPARM=1 USE_STATIC_PCRE=1 USE_PCRE_JIT=1 USE_TFO=1 USE_OPENSSL=1 DEFINE="-fstack-protector -Wformat -Wformat-security -Werror=format-security -D_FORTIFY_SOURCE=2" \
    && make install \
    && cd .. \
    && rm -Rf haproxy-1.5.12

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