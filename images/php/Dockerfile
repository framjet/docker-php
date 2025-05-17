ARG UPTRACK_SOURCE=php:fpm-alpine
ARG COMPOSER_VERSION=latest
FROM composer:${COMPOSER_VERSION} AS comp
FROM ${UPTRACK_SOURCE} AS base

LABEL org.opencontainers.image.authors="Aurimas Niekis <aurimas@niekis.lt>"


ARG PHP_EXTENSIONS="intl pdo pdo_mysql mbstring exif pcntl bcmath gd opcache xsl zip"
ARG PECL_EXTENSIONS="redis amqp"
ARG PHPIZE_DEPS_EXTRA=""
ARG PHPIZE_DEPS_RUNTIME_EXTRA=""

ENV PHP_INI_SCAN_DIR=":/usr/local/etc/php/custom.d"
ENV PHP_EXTENSIONS="${PHP_EXTENSIONS}"
ENV PECL_EXTENSIONS="${PECL_EXTENSIONS}"
ENV PHPIZE_DEPS_EXTRA="${PHPIZE_DEPS_EXTRA}"
ENV PHPIZE_DEPS_RUNTIME_EXTRA="${PHPIZE_DEPS_RUNTIME_EXTRA}"

WORKDIR /var/www/html

# persistent / runtime deps
RUN apk add --no-cache $PHPIZE_DEPS_RUNTIME_EXTRA \
		libpng \
        libzip \
        libxslt \
        rabbitmq-c-dev \
        grpc-cpp \
        ;

RUN \
    set -eux \
    \
    && apk add --no-cache --virtual .build-deps $PHPIZE_DEPS $PHPIZE_DEPS_EXTRA \
      git \
      libxslt-dev \
      libzip-dev \
      oniguruma-dev \
      libpng-dev \
      binutils \
      grpc-dev \
      \
    \
    && docker-php-source extract \
    \
    # Compile and install grpc extension (its 1000x faster than installing through pecl)
    \
    && GRPC_VERSION=$(apk info grpc -d | grep grpc | cut -d- -f2)  \
    && git clone --depth 1 -b v${GRPC_VERSION} https://github.com/grpc/grpc /tmp/grpc \
    && cd /tmp/grpc/src/php/ext/grpc \
    && phpize \
    && ./configure \
    && make -j $(nproc) \
    && make install \
    && rm -rf /tmp/grpc \
    && MAKEFLAGS="-j $(nproc)" pecl install opentelemetry \
    && docker-php-ext-enable grpc \
    && docker-php-ext-enable grpc opentelemetry \
    && sh -c 'test -n "$PHP_EXTENSIONS" && docker-php-ext-install -j$(nproc) $PHP_EXTENSIONS' \
    && sh -c 'test -n "$PECL_EXTENSIONS" && MAKEFLAGS="-j $(nproc)" pecl install $PECL_EXTENSIONS' \
    && sh -c 'test -n "$PHP_EXTENSIONS" && docker-php-ext-enable $PHP_EXTENSIONS' \
    && sh -c 'test -n "$PECL_EXTENSIONS" && docker-php-ext-enable $PECL_EXTENSIONS' \
    && docker-php-source delete \
    && { find /usr/local/lib -type f -print0 | xargs -0r strip --strip-all -p 2>/dev/null || true; } \
    && apk del .build-deps \
    && mkdir /docker-entrypoint.d \
    && mkdir /usr/local/etc/php-fpm.custom.d \
    && mkdir /usr/local/etc/php/custom.d \
    && sed -i 's/^access.log = \/proc\/self\/fd\/2/;access.log = \/proc\/self\/fd\/2/g' /usr/local/etc/php-fpm.d/docker.conf \
    ;

# Install Composer
COPY --from=comp --chown=root /usr/bin/composer /usr/local/bin/composer

# Copy configuration
COPY --chown=root ./conf.d/* /usr/local/etc/php/conf.d/
COPY --chown=root ./www.conf /usr/local/etc/php-fpm.d/www.conf
COPY --chown=root ./php-fpm.conf /usr/local/etc/php-fpm.conf

# Copy entrypoints
COPY --chown=root ./docker-entrypoint.d/* /docker-entrypoint.d/
COPY --chown=root ./docker-entrypoint.sh /docker-entrypoint.sh

# Copy minify script
COPY --chown=root ./minify.sh /usr/local/bin/php-minify

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["php-fpm"]

FROM base AS dev

ARG DEV_PHP_EXTENSIONS=""
ARG DEV_PECL_EXTENSIONS="xdebug"
ARG DEV_PHPIZE_DEPS_EXTRA=""
ARG DEV_PHPIZE_DEPS_RUNTIME_EXTRA=""

ENV DEV_PHP_EXTENSIONS="${DEV_PHP_EXTENSIONS}"
ENV DEV_PECL_EXTENSIONS="${DEV_PECL_EXTENSIONS}"
ENV DEV_PHPIZE_DEPS_EXTRA="${DEV_PHPIZE_DEPS_EXTRA}"
ENV DEV_PHPIZE_DEPS_RUNTIME_EXTRA="${DEV_PHPIZE_DEPS_RUNTIME_EXTRA}"

# persistent / runtime deps
RUN apk add --no-cache $DEV_PHPIZE_DEPS_RUNTIME_EXTRA \
        zsh \
		zsh-vcs \
        git \
        curl \
        vim \
        nano \
        shadow \
        ;

RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS $DEV_PHPIZE_DEPS_EXTRA \
      linux-headers \
      binutils \
      \
    \
    && docker-php-source extract \
    && { sh -c 'test -n "$DEV_PHP_EXTENSIONS" && docker-php-ext-install -j$(nproc) $DEV_PHP_EXTENSIONS' || true; } \
    && { sh -c 'test -n "$DEV_PECL_EXTENSIONS" && MAKEFLAGS="-j $(nproc)" pecl install $DEV_PECL_EXTENSIONS' || true; } \
    && { sh -c 'test -n "$DEV_PHP_EXTENSIONS" && docker-php-ext-enable $DEV_PHP_EXTENSIONS' || true; } \
    && { sh -c 'test -n "$DEV_PECL_EXTENSIONS" && docker-php-ext-enable $DEV_PECL_EXTENSIONS' || true; } \
    && docker-php-source delete \
    && { find /usr/local/lib -type f -print0 | xargs -0r strip --strip-all -p 2>/dev/null || true; } \
    && apk del .build-deps \
    \
    ;


# Copy dev configuration
COPY --chown=root ./conf.dev.d/* /usr/local/etc/php/conf.d/
COPY --chown=root ./www.dev.conf /usr/local/etc/php-fpm.d/www.conf

# Copy dev entrypoints
COPY --chown=root ./docker-entrypoint.dev.d/* /docker-entrypoint.d/

RUN apk add --no-cache   \
    && sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
    && sed -i 's/robbyrussell/agnoster/' /root/.zshrc \
    && sed -i 's/plugins=(git)/plugins=(git composer laravel laravel5 symfony)/' /root/.zshrc \
    && echo 'export PATH="$PATH:/var/www/html/vendor/bin"' >> /root/.zshrc \
    && chsh -s /bin/zsh

# Copy script to run zsh as bash terminal used in docker terminals
COPY --chown=root ./bash.sh /bin/bash

SHELL ["/bin/zsh"]

FROM dev AS dev-shell

COPY --chown=root ./php-shell-docker-entrypoint.sh /docker-entrypoint.sh


FROM base AS prod

ARG PROD_PHP_EXTENSIONS=""
ARG PROD_PECL_EXTENSIONS="xdebug"
ARG PROD_PHPIZE_DEPS_EXTRA=""
ARG PROD_PHPIZE_DEPS_RUNTIME_EXTRA=""

ENV PROD_PHP_EXTENSIONS="${PROD_PHP_EXTENSIONS}"
ENV PROD_PECL_EXTENSIONS="${PROD_PECL_EXTENSIONS}"
ENV PROD_PHPIZE_DEPS_EXTRA="${PROD_PHPIZE_DEPS_EXTRA}"
ENV PROD_PHPIZE_DEPS_RUNTIME_EXTRA="${PROD_PHPIZE_DEPS_RUNTIME_EXTRA}"

# persistent / runtime deps
RUN \
    test -n "$PROD_PHPIZE_DEPS_RUNTIME_EXTRA" \
    && sh -c 'apk add --no-cache $PROD_PHPIZE_DEPS_RUNTIME_EXTRA' \
    || true \
    ;

RUN test -n "$PROD_PHPIZE_DEPS_EXTRA" \
    && sh -c 'apk add --no-cache --virtual .build-deps $PHPIZE_DEPS $PROD_PHPIZE_DEPS_EXTRA linux-headers binutils' \
    || true
     \

RUN \
    docker-php-source extract \
    && { sh -c 'test -n "$PROD_PHP_EXTENSIONS" && docker-php-ext-install -j$(nproc) $PROD_PHP_EXTENSIONS' || true; } \
    && { sh -c 'test -n "$PROD_PECL_EXTENSIONS" && MAKEFLAGS="-j $(nproc)" pecl install $PROD_PECL_EXTENSIONS' || true; } \
    && { sh -c 'test -n "$PROD_PHP_EXTENSIONS" && docker-php-ext-enable $PROD_PHP_EXTENSIONS' || true; } \
    && { sh -c 'test -n "$PROD_PECL_EXTENSIONS" && docker-php-ext-enable $PROD_PECL_EXTENSIONS' || true; } \
    && docker-php-source delete \
    && { find /usr/local/lib -type f -print0 | xargs -0r strip --strip-all -p 2>/dev/null || true; } \
    && { (sh -c 'test -n "$PROD_PHPIZE_DEPS_EXTRA" && apk del .build-deps') || true; }

ARG APP_ENV=prod
ARG APP_DEBUG=false

ENV APP_ENV=${APP_ENV}
ENV APP_DEBUG=${APP_DEBUG}


# Copy prod configuration
COPY --chown=root ./conf.prod.d/* /usr/local/etc/php/conf.d/
COPY --chown=root ./www.prod.conf /usr/local/etc/php-fpm.d/www.conf

# Copy prod entrypoints
COPY --chown=root ./docker-entrypoint.prod.d/* /docker-entrypoint.d/

RUN  \
    rm -rf /usr/src/php.tar.xz \
    \
    ;
