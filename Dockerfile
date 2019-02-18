FROM php:7.2-fpm

# Update packages and install composer and PHP dependencies.
RUN touch /etc/apt/sources.list.d/pgdg.list
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main" >> /etc/apt/sources.list.d/pgdg.list
RUN apt-get update && apt dist-upgrade -y && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-unauthenticated \
    mysql-client \
    unzip \
    libtool \
    libxml2-dev \
    zip \
    libmagickwand-dev \
    postgresql-client \
    libpq-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libmcrypt-dev \
    libpng-dev \
    libbz2-dev \
    libzip-dev\
    curl \
    libcurl4-gnutls-dev \
    git \
    cron \
    sqlite3 \
    libsqlite3-dev \
    apt-utils \
    && pecl channel-update pecl.php.net \
    && pecl install apcu \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false npm \
    && rm -rf /var/lib/apt/lists/*
# Install PECL and PEAR extensions
RUN pecl install xdebug-2.7.0beta1 \
  && docker-php-ext-enable xdebug \
  && xdebug_ini=$(find /usr/local/etc/php/conf.d/ -name '*xdebug.ini') \
  && if [ -z "$xdebug_ini" ]; then xdebug_ini="/usr/local/etc/php/conf.d/xdebug.ini" && echo "zend_extension=$(find /usr/local/lib/php/extensions/ -name xdebug.so)" > $xdebug_ini; fi \
  && echo "xdebug.remote_enable=1"  >> $xdebug_ini \
  && echo "xdebug.remote_autostart=0" >> $xdebug_ini \
  && echo "xdebug.idekey=\"PHPSTORM\"" >> $xdebug_ini

# Install PHP_CodeSniffer
RUN curl -OL https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar
RUN curl -OL https://squizlabs.github.io/PHP_CodeSniffer/phpcbf.phar
RUN curl -OL http://static.phpmd.org/php/latest/phpmd.phar
RUN cp phpcs.phar /usr/local/bin/phpcs 
RUN chmod +x /usr/local/bin/phpcs 
RUN cp phpcbf.phar /usr/local/bin/phpcbf 
RUN chmod +x /usr/local/bin/phpcbf
RUN cp phpmd.phar /usr/local/bin/phpmd
RUN chmod +x /usr/local/bin/phpmd

# Install phpunit
RUN curl -OL https://phar.phpunit.de/phpunit.phar
RUN cp phpunit.phar /usr/local/bin/phpunit
RUN chmod +x /usr/local/bin/phpunit

# Install and enable php extensions

RUN docker-php-ext-install \
    curl \
    iconv \
    mbstring \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    pdo_sqlite \
    pcntl \
    tokenizer \
    xml \
    gd \
    zip \
    bcmath \
    bz2 \
    mysqli 

RUN docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql
RUN docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ 

RUN pecl install imagick \
RUN docker-php-ext-enable \
    imagick \
    mysqli \
    mbstring \
    zip \
    pdo_pgsql
    


# Memory Limit
RUN echo "memory_limit=2048M" > $PHP_INI_DIR/conf.d/memory-limit.ini
RUN echo "max_execution_time=900" >> $PHP_INI_DIR/conf.d/memory-limit.ini
RUN echo "extension=apcu.so" > $PHP_INI_DIR/conf.d/apcu.ini
RUN echo "post_max_size=20M" >> $PHP_INI_DIR/conf.d/memory-limit.ini
RUN echo "upload_max_filesize=20M" >> $PHP_INI_DIR/conf.d/memory-limit.ini

# Time Zone
RUN echo "date.timezone=${PHP_TIMEZONE:-UTC}" > $PHP_INI_DIR/conf.d/date_timezone.ini
# Display errors in stderr
RUN echo "display_errors=stderr" > $PHP_INI_DIR/conf.d/display-errors.ini

# Disable PathInfo
RUN echo "cgi.fix_pathinfo=0" > $PHP_INI_DIR/conf.d/path-info.ini

# Disable expose PHP
RUN echo "expose_php=0" > $PHP_INI_DIR/conf.d/path-info.ini

# Install Composer
# RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html