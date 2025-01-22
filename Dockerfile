FROM php:8.3-fpm
ENV ACCEPT_EULA=Y

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Install curl dan wget terlebih dahulu
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gnupg \
    apt-transport-https && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Add necessary keys and repositories
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    echo "deb https://packages.microsoft.com/config/debian/9/prod.list" > /etc/apt/sources.list.d/mssql-release.list && \
    echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    curl -sL https://deb.nodesource.com/setup_18.x | bash - && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

# Install all remaining dependencies
RUN apt-get update && apt-get install -y \
    git \
    lsb-release \
    gnupg2 \
    build-essential \
    python3 \
    memcached \
    default-mysql-client \
    unzip \
    libtool \
    libxml2-dev \
    zip \
    libmagickwand-dev \
    postgresql-client-14 \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libmcrypt-dev \
    libpng-dev \
    libbz2-dev \
    libzip-dev \
    libonig-dev \
    libcurl4-gnutls-dev \
    cron \
    sqlite3 \
    libsqlite3-dev \
    libgmp-dev \
    libpcre3 \
    libpcre3-dev \
    openssl \
    libssl-dev \
    libpq-dev \
    apt-utils \
    msodbcsql17 \
    unixodbc-dev \
    nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install PECL and PEAR extensions
RUN pecl channel-update pecl.php.net && \
    pecl install apcu xmlrpc-beta && \
    pecl install xdebug && \
    docker-php-ext-enable xdebug && \
    pecl install -o -f redis && \
    docker-php-ext-enable redis && \
    pecl install swoole && \
    echo "extension=swoole.so" > $PHP_INI_DIR/conf.d/swoole.ini

# Install Composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php && \
    php -r "unlink('composer-setup.php');" && \
    mv composer.phar /usr/local/bin/composer

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-configure bcmath --enable-bcmath && \
    docker-php-ext-configure intl --enable-intl && \
    docker-php-ext-configure pcntl --enable-pcntl && \
    docker-php-ext-configure mysqli --with-mysqli && \
    docker-php-ext-configure pdo_mysql --with-pdo-mysql && \
    docker-php-ext-configure pdo_pgsql && \
    docker-php-ext-configure mbstring --enable-mbstring && \
    docker-php-ext-configure soap --enable-soap && \
    docker-php-ext-configure gmp && \
    docker-php-ext-install -j$(nproc) gd bcmath intl pcntl mysqli pdo_mysql pdo pdo_pgsql pgsql soap zip bz2 gmp opcache exif fileinfo && \
    docker-php-ext-enable xmlrpc mysqli zip pdo_pgsql pdo_mysql

# PHP configuration
RUN echo "memory_limit=2048M" > $PHP_INI_DIR/conf.d/memory-limit.ini && \
    echo "max_execution_time=900" >> $PHP_INI_DIR/conf.d/memory-limit.ini && \
    echo "post_max_size=100M" >> $PHP_INI_DIR/conf.d/memory-limit.ini && \
    echo "upload_max_filesize=100M" >> $PHP_INI_DIR/conf.d/memory-limit.ini && \
    echo "date.timezone=UTC" > $PHP_INI_DIR/conf.d/date_timezone.ini && \
    echo "display_errors=stderr" > $PHP_INI_DIR/conf.d/display-errors.ini && \
    echo "cgi.fix_pathinfo=0" > $PHP_INI_DIR/conf.d/path-info.ini && \
    echo "expose_php=0" >> $PHP_INI_DIR/conf.d/path-info.ini

WORKDIR /var/www/html
# Configure Git to treat this directory as safe
RUN git config --global --add safe.directory /var/www/html

RUN npm -v
RUN php -i
