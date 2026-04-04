FROM php:8.5-fpm

ENV ACCEPT_EULA=Y
ENV DEBIAN_FRONTEND=noninteractive

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Base utilities + build dependencies
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    apt-transport-https \
    git \
    lsb-release \
    curl \
    ca-certificates \
    cron \
    unzip \
    libtool \
    libxml2-dev \
    libicu-dev \
    zlib1g \
    zip \
    libcurl4-gnutls-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libmcrypt-dev \
    libpng-dev \
    libbz2-dev \
    libzip-dev \
    libonig-dev \
    sqlite3 \
    libsqlite3-dev \
    libgmp-dev \
    libpcre2-dev \
    openssl \
    libssl-dev \
    libmagickwand-dev \
    python3 \
    nodejs \
    memcached \
    default-mysql-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Microsoft repo + PGDG repo + NodeSource
RUN curl -sSL -O https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb && \
    install -d /usr/share/postgresql-common/pgdg && \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
      -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc && \
    . /etc/os-release && \
    echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt ${VERSION_CODENAME}-pgdg main" \
      > /etc/apt/sources.list.d/pgdg.list && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get update && apt-get install -y \
      unixodbc \
      unixodbc-dev \
      msodbcsql18 \
      postgresql-client-18 \
      libpq-dev \
      nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# PECL extensions
# Setelah build stabil, lebih baik pin versinya secara eksplisit.
RUN pecl channel-update pecl.php.net

RUN pecl install swoole && docker-php-ext-enable swoole
RUN pecl install redis && docker-php-ext-enable redis
RUN pecl install xdebug && docker-php-ext-enable xdebug
RUN pecl install apcu && docker-php-ext-enable apcu
RUN pecl install xmlrpc-beta && docker-php-ext-enable xmlrpc

# Optional: aktifkan hanya bila aplikasi memang perlu SQL Server dari PHP
RUN pecl install sqlsrv && docker-php-ext-enable sqlsrv
RUN pecl install pdo_sqlsrv && docker-php-ext-enable pdo_sqlsrv

# Core PHP extensions from php-src
# Penting:
# - fileinfo TIDAK perlu diinstall (sudah enabled by default)
# - opcache TIDAK perlu diinstall di PHP 8.5 (sudah built-in)
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install -j1 \
      gd \
      bcmath \
      intl \
      pcntl \
      mysqli \
      pdo_mysql \
      pdo_pgsql \
      pgsql \
      soap \
      zip \
      bz2 \
      gmp \
      exif

# Composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    rm -f composer-setup.php

# QA tools
RUN curl -fsSLo /usr/local/bin/phpcs https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar && \
    curl -fsSLo /usr/local/bin/phpcbf https://squizlabs.github.io/PHP_CodeSniffer/phpcbf.phar && \
    curl -fsSLo /usr/local/bin/phpmd https://github.com/phpmd/phpmd/releases/download/2.15.0/phpmd.phar && \
    chmod +x /usr/local/bin/phpcs /usr/local/bin/phpcbf /usr/local/bin/phpmd

# PHPUnit
RUN curl -fsSLo /usr/local/bin/phpunit https://phar.phpunit.de/phpunit-10.phar && \
    chmod +x /usr/local/bin/phpunit

# php-fpm tuning
RUN sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i -e "s/pm.max_children = 5/pm.max_children = 40/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i -e "s/pm.start_servers = 2/pm.start_servers = 15/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 15/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 25/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i -e "s/;pm.max_requests = 500/pm.max_requests = 500/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i -e "s/;pm.status_path = \\/status/pm.status_path = \\/status/g" /usr/local/etc/php-fpm.d/www.conf

# PHP runtime settings
RUN { \
      echo "memory_limit=2048M"; \
      echo "max_execution_time=900"; \
      echo "post_max_size=100M"; \
      echo "upload_max_filesize=100M"; \
    } > "$PHP_INI_DIR/conf.d/runtime.ini"

# OPcache config for PHP 8.5
# Jangan pakai zend_extension=opcache.so
RUN { \
      echo "opcache.enable=1"; \
      echo "opcache.enable_cli=0"; \
      echo "opcache.memory_consumption=256"; \
      echo "opcache.interned_strings_buffer=16"; \
      echo "opcache.max_accelerated_files=20000"; \
      echo "opcache.validate_timestamps=0"; \
      echo "opcache.revalidate_freq=0"; \
    } > "$PHP_INI_DIR/conf.d/opcache.ini"

# Time zone
RUN echo "date.timezone=${PHP_TIMEZONE:-UTC}" > "$PHP_INI_DIR/conf.d/date_timezone.ini"

# Git safe directory
RUN git config --global --add safe.directory /var/www/html

WORKDIR /var/www/html

# Sanity check
RUN php -v && \
    php -m | sort && \
    php -i | grep -E "PDO|pgsql|sqlsrv|ODBC|xdebug|redis|swoole|APCu|Zend OPcache" || true && \
    composer --version && \
    node -v && npm -v
