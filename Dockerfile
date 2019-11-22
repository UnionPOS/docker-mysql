FROM unionpos/ubuntu:16.04

# grab gosu for easy step-down from root
COPY --from=unionpos/gosu:1.11 /gosu /usr/local/bin/

ENV MYSQL_MAJOR 5.7
ENV MYSQL_VERSION 5.7.27-1ubuntu16.04

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r mysql && useradd -r -g mysql mysql

RUN apt-get update && apt-get install -y --no-install-recommends \
	gnupg \
	dirmngr \
	# openssl for mysql_ssl_rsa_setup
	openssl \
	# FATAL ERROR: please install the following Perl modules before executing /usr/local/mysql/scripts/mysql_install_db:
	# File::Basename
	# File::Copy
	# Sys::Hostname
	# Data::Dumper
	perl \
	# pwgen for MYSQL_RANDOM_ROOT_PASSWORD
	pwgen \
	&& rm -rf /var/lib/apt/lists/*

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

RUN echo "deb http://repo.mysql.com/apt/ubuntu/ xenial mysql-${MYSQL_MAJOR}" > /etc/apt/sources.list.d/mysql.list \
	# set debconf keys to make APT a little quieter
	&& { \
	echo mysql-community-server mysql-community-server/data-dir select ''; \
	echo mysql-community-server mysql-community-server/root-pass password ''; \
	echo mysql-community-server mysql-community-server/re-root-pass password ''; \
	echo mysql-community-server mysql-community-server/remove-test-db select false; \
	} | debconf-set-selections \
	&& apt-get update && apt-get install -y mysql-server="${MYSQL_VERSION}" && rm -rf /var/lib/apt/lists/* \
	# the "/var/lib/mysql" stuff here is because the mysql-server postinst doesn't have an explicit way to disable the mysql_install_db codepath besides having a database already "configured" (ie, stuff in /var/lib/mysql/mysql)
	&& rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql /var/run/mysqld \
	&& chown -R mysql:mysql /var/lib/mysql /var/run/mysqld \
	# ensure that /var/run/mysqld (used for socket and lock files) is writable regardless of the UID our mysqld instance ends up having at runtime
	&& chmod 777 /var/run/mysqld \
	# comment out a few problematic configuration values
	&& find /etc/mysql/ -name '*.cnf' -print0 \
	| xargs -0 grep -lZE '^(bind-address|log)' \
	| xargs -rt -0 sed -Ei 's/^(bind-address|log)/#&/' \
	# don't reverse lookup hostnames, they are usually another container
	&& echo '[mysqld]\nskip-host-cache\nskip-name-resolve' > /etc/mysql/conf.d/docker.cnf

# EXPOSE 3306
VOLUME /var/lib/mysql

# create directory for seeding database
RUN mkdir /docker-entrypoint-initdb.d

COPY scripts/docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["mysqld"]
