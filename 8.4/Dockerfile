# if changing, make sure the deb command below is referencing the correct release like jammy
# 22.04 is jammy
FROM unionpos/ubuntu:24.04

# grab gosu for easy step-down from root
COPY --from=unionpos/gosu:1.11 /gosu /usr/local/bin/

ENV MYSQL_MAJOR 8.4
ENV MYSQL_VERSION 8.4.6-1ubuntu24.04



# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r mysql && useradd -r -g mysql mysql

RUN apt-get update && apt-get install -y --no-install-recommends gnupg dirmngr && rm -rf /var/lib/apt/lists/*

RUN mkdir /docker-entrypoint-initdb.d

RUN apt-get update && apt-get install -y --no-install-recommends gnupg dirmngr && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y --no-install-recommends \
	# for MYSQL_RANDOM_ROOT_PASSWORD
	pwgen \
	# for mysql_ssl_rsa_setup
	openssl \
	# FATAL ERROR: please install the following Perl modules before executing /usr/local/mysql/scripts/mysql_install_db:
	# File::Basename
	# File::Copy
	# Sys::Hostname
	# Data::Dumper
	perl \
	&& rm -rf /var/lib/apt/lists/_disabled_*  # disabled deleting all the existing lists

RUN set -ex \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& for server in $(shuf -e ha.pool.sks-keyservers.net \
	hkp://p80.pool.sks-keyservers.net:80 \
	keyserver.ubuntu.com \
	hkp://keyserver.ubuntu.com:80 \
	pgp.mit.edu) ; do \
	gpg --keyserver "$server" --recv-keys A4A9406876FCBD3C456770C88C718D3B5072E1F5 && break || : ; \
	done \
	&& gpg --export "A4A9406876FCBD3C456770C88C718D3B5072E1F5" > /etc/apt/trusted.gpg.d/mysql.gpg \
	&& rm -rf "$GNUPGHOME" \
	&& apt-key list > /dev/null

# Install required dependencies and add MySQL APT repository GPG key
RUN apt-get update && \
	apt upgrade -y && \
    apt-get install -y wget gnupg lsb-release && \
    wget https://dev.mysql.com/get/mysql-apt-config_0.8.34-1_all.deb && \
	dpkg -i mysql-apt-config_0.8.34-1_all.deb && \
	apt-get update

# Update the package list
RUN apt-get update && apt-get install -y mysql-server  \
  && rm -rf /var/lib/apt/lists/* \
	&& rm -rf /var/lib/mysql  \
  && mkdir -p /var/lib/mysql /var/run/mysqld \
	&& chown -R mysql:mysql /var/lib/mysql /var/run/mysqld \
	# ensure that /var/run/mysqld (used for socket and lock files) is writable regardless of the UID our mysqld instance ends up having at runtime
	&& chmod 777 /var/run/mysqld

VOLUME /var/lib/mysql
# Config files
COPY config/ /etc/mysql/
COPY scripts/docker-entrypoint.sh /usr/local/bin/
RUN ln -s usr/local/bin/docker-entrypoint.sh /entrypoint.sh # backwards compat

ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 3306 33060
CMD ["mysqld"]
