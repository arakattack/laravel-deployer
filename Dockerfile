FROM php:8.4-fpm
ENV ACCEPT_EULA=Y

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Install utilities
RUN sudo add-apt-repository universe
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    apt-transport-https \
    git \
    lsb-release \
    curl \
    cron \
    unzip \
    libtool \
    libxml2-dev \
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
    libpcre3 \
    libpcre3-dev \
    openssl \
    libssl-dev \
    libmagickwand-dev \
    python3 \
    nodejs \
    memcached \
    default-mysql-client \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Microsoft ODBC Driver and Postgres Client
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/debian/9/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    wget https://deb.sipwise.com/debian/pool/main/g/glibc/multiarch-support_2.24-11+deb9u4_amd64.deb && \
    dpkg -i multiarch-support_2.24-11+deb9u4_amd64.deb && \
    touch /etc/apt/sources.list.d/pgdg.list && \
    echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    curl -sL https://deb.nodesource.com/setup_20.x | /bin/bash - && \
    apt-get update && apt-get install -y msodbcsql17 unixodbc-dev postgresql-client-14 libpq-dev nodejs

# Install swoole
RUN pecl install swoole && \
    touch $PHP_INI_DIR/conf.d/swoole.ini && \
    echo "extension=swoole.so" > $PHP_INI_DIR/conf.d/swoole.ini

# Install PECL extensions
RUN pecl install xdebug && \
    docker-php-ext-enable xdebug && \
    pecl install redis && \
    docker-php-ext-enable redis

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd bcmath intl pcntl mysqli pdo_mysql pdo_pgsql pgsql soap zip bz2 gmp opcache exif fileinfo \
    && docker-php-ext-enable gd bcmath intl pcntl mysqli pdo_mysql pdo_pgsql pgsql soap zip bz2 gmp opcache exif fileinfo

# Install XML-RPC 
RUN pecl install apcu xmlrpc-beta && \
    docker-php-ext-enable xmlrpc  
    
# Install Composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php && \
    php -r "unlink('composer-setup.php');" && \
    mv composer.phar /usr/local/bin/composer

# Install PHP_CodeSniffer and related tools
RUN curl -OL https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar && \
    curl -OL https://squizlabs.github.io/PHP_CodeSniffer/phpcbf.phar && \
    curl -OL https://github.com/phpmd/phpmd/releases/download/2.8.2/phpmd.phar && \
    cp phpcs.phar /usr/local/bin/phpcs && \
    chmod +x /usr/local/bin/phpcs && \
    cp phpcbf.phar /usr/local/bin/phpcbf && \
    chmod +x /usr/local/bin/phpcbf && \
    cp phpmd.phar /usr/local/bin/phpmd && \
    chmod +x /usr/local/bin/phpmd

# Install PHPUnit
RUN curl -OL https://phar.phpunit.de/phpunit-8.5.3.phar && \
    cp phpunit-8.5.3.phar /usr/local/bin/phpunit && \
    chmod +x /usr/local/bin/phpunit

# Tweak php-fpm and PHP configurations
RUN sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i -e "s/pm.max_children = 5/pm.max_children = 40/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i -e "s/pm.start_servers = 2/pm.start_servers = 15/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 15/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 25/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i -e "s/;pm.max_requests = 500/pm.max_requests = 500/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i -e "s/;pm.status_path/pm.status_path/g" /usr/local/etc/php-fpm.d/www.conf

# Memory and execution limits
RUN echo "memory_limit=2048M" > $PHP_INI_DIR/conf.d/memory-limit.ini && \
    echo "max_execution_time=900" >> $PHP_INI_DIR/conf.d/memory-limit.ini && \
    echo "post_max_size=100M" >> $PHP_INI_DIR/conf.d/memory-limit.ini && \
    echo "upload_max_filesize=100M" >> $PHP_INI_DIR/conf.d/memory-limit.ini && \
    echo "extension=apcu.so" > $PHP_INI_DIR/conf.d/apcu.ini

# Time Zone
RUN echo "date.timezone=${PHP_TIMEZONE:-UTC}" > $PHP_INI_DIR/conf.d/date_timezone.ini

# Configure Git to treat the directory as safe
RUN git config --global --add safe.directory /var/www/html

# Set the working directory
WORKDIR /var/www/html

# Check versions of installed tools
RUN npm -v && php -i
