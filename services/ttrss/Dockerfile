FROM php:fpm

ENV DB_TYPE pgsql
ENV DB_HOST ashtonc-postgres
ENV DB_PORT 5432
ENV DB_NAME ttrss
ENV DB_USER postgres
ENV DB_PASS postgres
ENV SELF_URL_PATH https://rss.ashtonc.ca

ADD configure-db.php /configure-db.php
ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN set -x \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests --assume-yes \
       curl \
       tar \
       supervisor \
       ca-certificates \
       libpq-dev \
       libpcre3-dev \
    && docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql \
    && docker-php-ext-install \
       fileinfo \
       json \
       opcache \
       pdo \
       pdo_pgsql \
       pgsql \
       pcntl \
    && apt-get clean

WORKDIR /var/www

RUN curl -SL https://git.tt-rss.org/fox/tt-rss/archive/master.tar.gz | tar xzC /var/www --strip-components 1 \
    && rm -rf */.empty */*/.empty *.md *.pot .gitignore utils

RUN chown www-data:www-data -R /var/www
RUN usermod --shell /bin/bash www-data

RUN cp config.php-dist config.php

VOLUME /var/www

CMD php /configure-db.php && supervisord -c /etc/supervisor/conf.d/supervisord.conf

