FROM php:8.0-fpm
ENV ACCEPT_EULA=Y

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
# Install selected extensions and other stuff
RUN apt-get update \ 
   && apt-get -y --no-install-recommends install apt-utils libc-ares-dev libxml2-dev gnupg apt-transport-https \ 
   && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* 

# Install git
RUN apt-get update \ 
   && apt-get -y install git \ 
   && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* 

#Install ODBC Driver
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \ 
   && curl https://packages.microsoft.com/config/debian/9/prod.list > /etc/apt/sources.list.d/mssql-release.list \ 
   && apt-get update 

# Install sqlsrv
RUN apt-get update
RUN apt-get install -y wget
RUN wget http://repo.libertas.pbh.gov.br/libertas/pool/main/g/glibc/multiarch-support_2.24-11+deb9u4_amd64.deb \
   && dpkg -i multiarch-support_2.24-11+deb9u4_amd64.deb
RUN apt-get -y install msodbcsql17 unixodbc-dev
RUN pecl install sqlsrv pdo_sqlsrv
RUN touch $PHP_INI_DIR/conf.d/sqlsrv.ini && echo "extension=sqlsrv.so" > $PHP_INI_DIR/conf.d/sqlsrv.ini
RUN touch $PHP_INI_DIR/conf.d/pdo_sqlsrv.ini && echo "extension=pdo_sqlsrv.so" > $PHP_INI_DIR/conf.d/pdo_sqlsrv.ini

# Update packages and install composer and PHP dependencies.
RUN curl -sL https://deb.nodesource.com/setup_16.x | /bin/bash -
RUN apt-get update && apt dist-upgrade -y && apt-get install gnupg2 -y
RUN touch /etc/apt/sources.list.d/pgdg.list
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ bullseye-pgdg main" >> /etc/apt/sources.list.d/pgdg.list
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 7FCC7D46ACCC4CF8
RUN apt-get update && apt dist-upgrade -y --allow-unauthenticated && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-unauthenticated \
  build-essential \
  nodejs \
  python2.7 \
  memcached \
  default-mysql-client \
  unzip \
  libtool \
  libxml2-dev \
  zip \
  libmagickwand-dev \
  postgresql-client-10 \
  libpq-dev \
  libfreetype6-dev \
  libjpeg62-turbo-dev \
  libmcrypt-dev \
  libpng-dev \
  libbz2-dev \
  libzip-dev \
  libonig-dev \
  curl \
  libcurl4-gnutls-dev \
  git \
  cron \
  sqlite3 \
  libsqlite3-dev \
  apt-utils \
  libgmp-dev \
  && pecl channel-update pecl.php.net \
  && pecl install apcu \
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false npm \
  && rm -rf /var/lib/apt/lists/*
RUN ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h
RUN curl -L https://www.npmjs.com/install.sh | sh  

# Install swoole
RUN pecl install -D 'enable-sockets="no" enable-openssl="yes" enable-http2="yes" enable-mysqlnd="yes" enable-swoole-json="no" enable-swoole-curl="yes" enable-cares="yes" with-postgres="yes"' swoole
RUN touch $PHP_INI_DIR/conf.d/swoole.ini && echo "extension=swoole.so" > $PHP_INI_DIR/conf.d/swoole.ini

# Install PECL and PEAR extensions
RUN pecl install xdebug \
  && docker-php-ext-enable xdebug \
  && xdebug_ini=$(find /usr/local/etc/php/conf.d/ -name '*xdebug.ini') \
  && if [ -z "$xdebug_ini" ]; then xdebug_ini="/usr/local/etc/php/conf.d/xdebug.ini" && echo "zend_extension=$(find /usr/local/lib/php/extensions/ -name xdebug.so)" > $xdebug_ini; fi \
  && echo "xdebug.remote_enable=1"  >> $xdebug_ini \
  && echo "xdebug.remote_autostart=0" >> $xdebug_ini \
  && echo "xdebug.idekey=\"PHPSTORM\"" >> $xdebug_ini

# Install redis
RUN pecl install -o -f redis \
  &&  rm -rf /tmp/pear \
  &&  docker-php-ext-enable redis

# Install PHP_CodeSniffer
RUN curl -OL https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar
RUN curl -OL https://squizlabs.github.io/PHP_CodeSniffer/phpcbf.phar
RUN curl -OL https://github.com/phpmd/phpmd/releases/download/2.8.2/phpmd.phar
RUN cp phpcs.phar /usr/local/bin/phpcs 
RUN chmod +x /usr/local/bin/phpcs 
RUN cp phpcbf.phar /usr/local/bin/phpcbf 
RUN chmod +x /usr/local/bin/phpcbf
RUN cp phpmd.phar /usr/local/bin/phpmd
RUN chmod +x /usr/local/bin/phpmd

# Install phpunit
RUN curl -OL https://phar.phpunit.de/phpunit-8.5.3.phar
RUN cp phpunit-8.5.3.phar /usr/local/bin/phpunit
RUN chmod +x /usr/local/bin/phpunit

# Add opcache configuration file
RUN echo "\
opcache.enable=1 \n\
opcache.memory_consumption=1024 \n\
opcache.interned_strings_buffer=128 \n\
opcache.max_accelerated_files=32531 \n\
opcache.validate_timestamps=0 \n\
opcache.save_comments=1 \n\
opcache.fast_shutdown=0 \n\
opcache.enable_cli=1 \n\
" > $PHP_INI_DIR/conf.d/opcache.ini

RUN docker-php-ext-configure gd \
  --with-freetype \
  --with-jpeg \
  && docker-php-ext-configure bcmath --enable-bcmath \
  && docker-php-ext-configure intl --enable-intl \
  && docker-php-ext-configure pcntl --enable-pcntl \
  && docker-php-ext-configure pgsql \
  && docker-php-ext-configure mysqli --with-mysqli \
  && docker-php-ext-configure pdo_mysql --with-pdo-mysql \
  && docker-php-ext-configure pdo_pgsql \
  && docker-php-ext-configure mbstring --enable-mbstring \
  && docker-php-ext-configure soap --enable-soap \
  && docker-php-ext-configure gmp

# Install and enable php extensions
RUN docker-php-ext-install -j$(nproc) gd \
  bcmath \
  intl \
  pcntl \
  mysqli \
  pdo_mysql \
  pdo \
  pdo_pgsql \
  pgsql \
  soap \
  zip \
  bz2 \
  gmp \
  opcache \
  exif \
  fileinfo
RUN pecl install imagick xmlrpc-beta
RUN docker-php-ext-enable \
  xmlrpc \
  imagick \
  mysqli \
  zip \
  pdo_pgsql \
  pdo_mysql

# Install redis
RUN pecl install -o -f redis \
  &&  rm -rf /tmp/pear \
  &&  docker-php-ext-enable redis

# tweak php-fpm config
RUN sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /usr/local/etc/php-fpm.d/www.conf && \
  sed -i -e "s/pm.max_children = 5/pm.max_children = 40/g" /usr/local/etc/php-fpm.d/www.conf && \
  sed -i -e "s/pm.start_servers = 2/pm.start_servers = 15/g" /usr/local/etc/php-fpm.d/www.conf && \
  sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 15/g" /usr/local/etc/php-fpm.d/www.conf && \
  sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 25/g" /usr/local/etc/php-fpm.d/www.conf && \
  sed -i -e "s/;pm.max_requests = 500/pm.max_requests = 500/g" /usr/local/etc/php-fpm.d/www.conf && \
  sed -i -e "s/;pm.status_path/pm.status_path/g" /usr/local/etc/php-fpm.d/www.conf


# Memory Limit
RUN echo "memory_limit=2048M" > $PHP_INI_DIR/conf.d/memory-limit.ini
RUN echo "max_execution_time=900" >> $PHP_INI_DIR/conf.d/memory-limit.ini
RUN echo "extension=apcu.so" > $PHP_INI_DIR/conf.d/apcu.ini
RUN echo "post_max_size=100M" >> $PHP_INI_DIR/conf.d/memory-limit.ini
RUN echo "upload_max_filesize=100M" >> $PHP_INI_DIR/conf.d/memory-limit.ini

# Time Zone
RUN echo "date.timezone=${PHP_TIMEZONE:-UTC}" > $PHP_INI_DIR/conf.d/date_timezone.ini
# Display errors in stderr
RUN echo "display_errors=stderr" > $PHP_INI_DIR/conf.d/display-errors.ini

# Disable PathInfo
RUN echo "cgi.fix_pathinfo=0" > $PHP_INI_DIR/conf.d/path-info.ini

# Disable expose PHP
RUN echo "expose_php=0" > $PHP_INI_DIR/conf.d/path-info.ini

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

WORKDIR /var/www/html
RUN npm -v
RUN php -i
