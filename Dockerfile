ARG PHP_IMAGE_VERSION=8.5.6-fpm

FROM php:${PHP_IMAGE_VERSION}

USER root
# Install packages:
RUN DEBIAN_FRONTEND=noninteractive \
	apt-get update \
	&& apt-get install -y --no-install-recommends \
	    nginx \
	    supervisor \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure, build, install and activate PHP extensions
COPY --from=ghcr.io/mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN \
    # php ext config - gd: disable AVIF \
    IPE_GD_WITHOUTAVIF=1 \
    \
    /usr/local/bin/install-php-extensions \
    # == Composer prerequisites: \
    zip \
    # \
    # == Symfony common prereqs: \
    intl \
    # \
    # == Image manipulation: \
    gd \
    # - alternative for better image processing: \
    # imagick \
    # \
    # == Databases: \
    # - MySQL \
    mysqli \
    pdo_mysql \
    # - Postgres \
    #pgsql \
    #pdo_pgsql \
    # \
    # == Queues: RabbitMQ & friends \
    # amqp \
    # \
    # == Tracing, logging, profiling \
    # opentelemetry \
    # blackfire \
    # \
    # == Protobuf & gRPC \
    # protobuf \
    # grpc \
    # \
    # == Columnar DBs: \
    # Clickhouse: \
    # seasclick \
    # \
    # == Key-Value stores \
    # memcached \
    redis

# Pre-install composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1

# Configure nginx
RUN rm /etc/nginx/sites-enabled/default
COPY config/nginx/nginx.conf /etc/nginx/nginx.conf
COPY config/nginx/default.conf /etc/nginx/conf.d/default.conf
# Configure PHP-FPM
COPY config/php/fpm-pool.conf /usr/local/etc/php-fpm.d/www.conf
COPY config/php/php.ini /usr/local/etc/php/conf.d/custom.ini
ENV LOG_CHANNEL=stderr
# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY config/stop-supervisord.sh /sbin/stop-supervisord.sh

# Expose the port nginx is reachable on
EXPOSE 8080
# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping
# Let supervisord start nginx & php-fpm
COPY config/entrypoint.sh /app/entrypoint.sh
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
# Copy dummy welcome page
COPY ./public/ /app/src/
WORKDIR /app/src/
