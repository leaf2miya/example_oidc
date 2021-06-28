FROM php:7.4.3-apache

RUN apt-get update \
    && apt-get install -y libapache2-mod-auth-openidc

RUN mkdir -p /var/www/html/secure/
COPY ./test.php /var/www/html/secure/
# COPY ./auth_openidc.conf /etc/apache2/mods-available/auth_openidc.conf

