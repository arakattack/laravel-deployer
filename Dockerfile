FROM php:8.2-fpm
ENV ACCEPT_EULA=Y

# Move production php.ini
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Install selected extensions and other stuff
RUN apt-get update && apt-get -y --no-install-recommends install \
    libc-ares-dev apt-utils libxml2-dev gnupg apt-transport-https \
    git wget curl build-essential nodejs python3 memcached default-mysql-client \
    unzip libtool libssl-dev libmagickwand-dev postgresql-client-12 libpq-dev \
    libfreetype6-dev libjpeg62-turbo-dev libmcrypt-dev libpng-dev libbz2-dev \
    libzip-dev libonig-dev libcurl4-gnutls-dev cron sqlite3 libsqlite3-dev \
    apt-utils libgmp-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

# Install ODBC Driver
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/debian/9/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && apt-get install -y msodbcsql17 unixodbc-dev && \
    pecl install sqlsrv pdo_sqlsrv && \
    docker-php-ext-enable sqlsrv pdo_sqlsrv

# Install Composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php && \
    php -r "unlink('composer-setup.php');" && \
    mv composer.phar /usr/local/bin/composer

# Install PECL and PEAR extensions
RUN pecl install xdebug redis apcu imagick xmlrpc-beta swoole && \
    docker-php-ext-enable xdebug redis apcu imagick xmlrpc swoole

# Install PHP_CodeSniffer, phpmd, phpunit
RUN curl -OL https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar && \
    curl -OL https://squizlabs.github.io/PHP_CodeSniffer/phpcbf.phar && \
    curl -OL https://github.com/phpmd/phpmd/releases/download/2.8.2/phpmd.phar && \
    curl -OL https://phar.phpunit.de/phpunit-8.5.3.phar && \
    mv phpcs.phar /usr/local/bin/phpcs && chmod +x /usr/local/bin/phpcs && \
    mv phpcbf.phar /usr/local/bin/phpcbf && chmod +x /usr/local/bin/phpcbf && \
    mv phpmd.phar /usr/local/bin/phpmd && chmod +x /usr/local/bin/phpmd && \
    mv phpunit-8.5.3.phar /usr/local/bin/phpunit && chmod +x /usr/local/bin/phpunit

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

# Configure PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-configure bcmath --enable-bcmath && \
    docker-php-ext-configure intl --enable-intl && \
    docker-php-ext-configure pcntl --enable-pcntl && \
    docker-php-ext-configure pgsql && \
    docker-php-ext-configure mysqli --with-mysqli && \
    docker-php-ext-configure pdo_mysql --with-pdo-mysql && \
    docker-php-ext-configure pdo_pgsql && \
    docker-php-ext-configure mbstring --enable-mbstring && \
    docker-php-ext-configure soap --enable-soap && \
    docker-php-ext-configure gmp && \
    docker-php-ext-install -j$(nproc) gd bcmath intl pcntl mysqli pdo_mysql pdo pdo_pgsql pgsql soap zip bz2 gmp opcache exif fileinfo

# Tweak php-fpm config
RUN sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i -e "s/pm.max_children = 5/pm.max_children = 40/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i -e "s/pm.start_servers = 2/pm.start_servers = 15/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 15/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 25/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i -e "s/;pm.max_requests = 500/pm.max_requests = 500/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i -e "s/;pm.status_path/pm.status_path/g" /usr/local/etc/php-fpm.d/www.conf

# Memory Limit
RUN echo "memory_limit=2048M" > $PHP_INI_DIR/conf.d/memory-limit.ini && \
    echo "max_execution_time=900" >> $PHP_INI_DIR/conf.d/memory-limit.ini && \
    echo "extension=apcu.so" > $PHP_INI_DIR/conf.d/apcu.ini && \
    echo "post_max_size=100M" >> $PHP_INI_DIR/conf.d/memory-limit.ini && \
    echo "upload_max_filesize=100M" >> $PHP_INI_DIR/conf.d/memory-limit.ini

# Time Zone
RUN echo "date.timezone=${PHP_TIMEZONE:-UTC}" > $PHP_INI_DIR/conf.d/date_timezone.ini

# Display errors in stderr
RUN echo "display_errors=stderr" > $PHP_INI_DIR/conf.d/display-errors.ini

# Disable PathInfo and expose PHP
RUN echo "cgi.fix_pathinfo=0" > $PHP_INI_DIR/conf.d/path-info.ini && \
    echo "expose_php=0" > $PHP_INI_DIR/conf.d/path-info.ini

# Configure Git to treat this directory as safe
RUN git config --global --add safe.directory /var/www/html

WORKDIR /var/www/html
RUN npm -v
RUN php -i
