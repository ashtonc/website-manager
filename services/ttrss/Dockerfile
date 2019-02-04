FROM debian:stretch-slim

ENV DB_TYPE pgsql
ENV DB_HOST ashtonc-postgres
ENV DB_PORT 5432
ENV DB_NAME ttrss
ENV DB_USER postgres
ENV DB_PASS postgres
ENV SELF_URL_PATH https://ttrss.ashtonc.ca

RUN set -x \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests --assume-yes \
       supervisor \
       ca-certificates \
       nginx \
       git \
       curl \
       tar \
       php7.0 \
       php7.0-apcu \
       php7.0-cli \
       php7.0-curl \
       php7.0-dom \
       php7.0-fileinfo \
       php7.0-fpm \
       php7.0-gd \
       php7.0-iconv \
       php7.0-intl \
       php7.0-json \
       php7.0-mbstring \
       php7.0-mcrypt \
       php7.0-opcache \
       php7.0-pdo \
       php7.0-pgsql \
       php7.0-posix \
       php7.0-xml \
    && apt-get clean

RUN phpenmod mcrypt
RUN mkdir -p /run/php

WORKDIR /var/www
RUN curl -SL https://git.tt-rss.org/fox/tt-rss/archive/master.tar.gz | tar xzC /var/www --strip-components 1 \
    && rm -rf */.empty */*/.empty *.md *.pot .gitignore utils \
    && chown www-data:www-data -R /var/www
RUN cp config.php-dist config.php

ADD configure-db.php /configure-db.php
ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf
ADD nginx.internal.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD php /configure-db.php && supervisord -c /etc/supervisor/conf.d/supervisord.conf

