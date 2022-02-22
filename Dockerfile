FROM alpine:3.14

RUN apk add --update nodejs

RUN apk add -q \
    autoconf \
    automake \
    build-base \
    curl \
    ca-certificates \
    cpio \
    git \
    gzip \
    libedit-dev \
    libtool \
    libunwind-dev \
    linux-headers \
    npm \
    make \
    pcre2-dev \
    py-docutils \
    py3-sphinx \
    tar \
    sudo

RUN curl -L https://github.com/DarthSim/hivemind/releases/download/v1.1.0/hivemind-v1.1.0-linux-amd64.gz -o hivemind.gz \
  && gunzip hivemind.gz \
  && mv hivemind /usr/local/bin

ENV VARNISH_SIZE 100M

RUN set -e;\
    BASE_PKGS="tar alpine-sdk sudo git"; \
    apk add --virtual varnish-build-deps -q --no-progress --update $BASE_PKGS; \
    git clone https://github.com/varnishcache/pkg-varnish-cache.git; \
    cd pkg-varnish-cache/alpine; \
    git checkout d3e6a3fad7d4c2ac781ada92dcc246e7eef9d129; \
    sed -i APKBUILD \
        -e "s/pkgver=@VERSION@/pkgver=7.0.2/" \
  -e 's@^source=.*@source="https://varnish-cache.org/downloads/varnish-$pkgver.tgz"@' \
  -e "s/^sha512sums=.*/sha512sums=\"5eb08345c95152639266b7ad241185188477f8fd04e88e4dfda1579719a1a413790a0616f25d70994f6d3b8f7640ea80926ece7c547555dad856fd9f6960c9a3  varnish-\$pkgver.tgz\"/"; \
    adduser -D builder; \
    echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers; \
    addgroup builder abuild; \
    su builder -c "abuild-keygen -nai"; \
    chown builder -R .; \
    su builder -c "abuild -r";\
    apk add --allow-untrusted ~builder/packages/pkg-varnish-cache/*/*.apk; \
    echo -e 'vcl 4.1;\nbackend default none;' > /etc/varnish/default.vcl; \
    apk del --no-network varnish-build-deps; \
    rm -rf ~builder /pkg-varnish-cache; \
    sed -i '/^builder/d' /etc/sudoers; \
    deluser --remove-home builder;

RUN git clone --branch master --single-branch https://github.com/varnish/varnish-modules.git
WORKDIR /varnish-modules
RUN ./bootstrap && \
    ./configure && \
    make && \
    make check -j 4 && \
    make install

WORKDIR /app

COPY . .
COPY default.vcl /etc/varnish/default.vcl
COPY Procfile Procfile

RUN chmod +x /usr/local/bin/hivemind
RUN chmod +x /app/scripts/*.sh

RUN npm install --production

EXPOSE 3000 8080
ENV PORT=3000

RUN ["chmod", "+w", "/dev/stdout"]

CMD ["/usr/local/bin/hivemind"]