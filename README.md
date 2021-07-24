<pre>
                __        __  __           __  
 ___ ________ _/ /_____ _/ /_/ /____ _____/ /__
/ _ `/ __/ _ `/  '_/ _ `/ __/ __/ _ `/ __/  '_/
\_,_/_/  \_,_/_/\_\\_,_/\__/\__/\_,_/\__/_/\_\ 
            ___/ /__ ___  / /__  __ _____ ____ 
           / _  / -_) _ \/ / _ \/ // / -_) __/ 
           \_,_/\__/ .__/_/\___/\_, /\__/_/    
                  /_/          /___/           
</pre>

PHP 8.0, Nodejs 10.x, npm 6.12.x , python 2.7 

![Docker Image CI](https://github.com/arakattack/laravel-deployer/workflows/Docker%20Image%20CI/badge.svg?branch=master)
# Usage

## Dockerfile
<pre>
FROM arakattack/laravel-deployer:latest

ADD . /var/www/html
COPY . /var/www/html
WORKDIR /var/www/html


RUN touch storage/logs/laravel.log
RUN composer global require hirak/prestissimo
RUN composer install
COPY .env.example .env
RUN php artisan view:clear
RUN php artisan config:clear
RUN php artisan cache:clear
RUN php artisan vendor:publish --all
RUN php artisan storage:link
RUN composer  dump-autoload

RUN chmod -R 777 /var/www/html/storage
RUN chmod -R 755 /var/www/html/vendor
</pre>
