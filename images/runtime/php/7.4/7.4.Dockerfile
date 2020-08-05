ARG DEBIAN_FLAVOR

# From https://github.com/docker-library/php.git
FROM php-run-base-${DEBIAN_FLAVOR}

ENV PHP_VERSION="7.4.3"
ENV PHP_INI_DIR="/usr/local/etc/php" \
	APACHE_CONFDIR="/etc/apache2" \
	APACHE_ENVVARS="$APACHE_CONFDIR/envvars" \
	PHP_EXTRA_BUILD_DEPS="apache2-dev" \
	PHP_EXTRA_CONFIGURE_ARGS="--with-apxs2 --disable-cgi" \
	# Apply stack smash protection to functions using local buffers and alloca()
	# Make PHP's main executable position-independent (improves ASLR security mechanism, and has no performance impact on x86_64)
	# Enable optimization (-O2)
	# Enable linker optimization (this sorts the hash buckets to improve cache locality, and is non-default)
	# Adds GNU HASH segments to generated executables (this is used if present, and is much faster than sysv hash; in this configuration, sysv hash is also generated)
	# https://github.com/docker-library/php/issues/272
	# -D_LARGEFILE_SOURCE and -D_FILE_OFFSET_BITS=64 (https://www.php.net/manual/en/intro.filesystem.php)
	PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64" \
	PHP_CPPFLAGS="$PHP_CFLAGS" \
	PHP_LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie" \
	GPG_KEYS="42670A7FE4D0441C8E4632349E4FDC074A4EF02D 5A52880781F755608BF815FC910DEB46F53EA312" \
	PHP_URL="https://www.php.net/get/php-$PHP_VERSION.tar.xz/from/this/mirror" \
	PHP_ASC_URL="https://www.php.net/get/php-$PHP_VERSION.tar.xz.asc/from/this/mirror" \
	PHP_SHA256="cf1f856d877c268124ded1ede40c9fb6142b125fdaafdc54f855120b8bc6982a" \
	PHP_MD5=""

# Install the Microsoft SQL Server PDO driver on supported versions only.
#  - https://docs.microsoft.com/en-us/sql/connect/php/installation-tutorial-linux-mac
#  - https://docs.microsoft.com/en-us/sql/connect/odbc/linux-mac/installing-the-microsoft-odbc-driver-for-sql-server
RUN set -eux \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		gnupg2 \
		apt-transport-https \
	&& curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
	&& curl https://packages.microsoft.com/config/debian/9/prod.list > /etc/apt/sources.list.d/mssql-release.list \
	&& apt-get update \
	&& ACCEPT_EULA=Y apt-get install -y msodbcsql17 unixodbc-dev \
	mkdir -p "$PHP_INI_DIR/conf.d"; \
	# allow running as an arbitrary user (https://github.com/docker-library/php/issues/743)
	[ ! -d /var/www/html ]; \
	mkdir -p /var/www/html; \
	chown www-data:www-data /var/www/html; \
	chmod 777 /var/www/html \
	apt-get update; \
	apt-get install -y --no-install-recommends apache2; \
	rm -rf /var/lib/apt/lists/*; \
	\
	# generically convert lines like
	#   export APACHE_RUN_USER=www-data
	# into
	#   : ${APACHE_RUN_USER:=www-data}
	#   export APACHE_RUN_USER
	# so that they can be overridden at runtime ("-e APACHE_RUN_USER=...")
	sed -ri 's/^export ([^=]+)=(.*)$/: ${\1:=\2}\nexport \1/' "$APACHE_ENVVARS"; \
	\
	# setup directories and permissions
	. "$APACHE_ENVVARS"; \
	for dir in \
		"$APACHE_LOCK_DIR" \
		"$APACHE_RUN_DIR" \
		"$APACHE_LOG_DIR" \
	; do \
		rm -rvf "$dir"; \
		mkdir -p "$dir"; \
		chown "$APACHE_RUN_USER:$APACHE_RUN_GROUP" "$dir"; \
	# allow running as an arbitrary user (https://github.com/docker-library/php/issues/743)
		chmod 777 "$dir"; \
	done; \
	\
	# delete the "index.html" that installing Apache drops in here
	rm -rvf /var/www/html/*; \
	\
	# logs should go to stdout / stderr
	ln -sfT /dev/stderr "$APACHE_LOG_DIR/error.log"; \
	ln -sfT /dev/stdout "$APACHE_LOG_DIR/access.log"; \
	ln -sfT /dev/stdout "$APACHE_LOG_DIR/other_vhosts_access.log"; \
	chown -R --no-dereference "$APACHE_RUN_USER:$APACHE_RUN_GROUP" "$APACHE_LOG_DIR" \
	# Apache + PHP requires preforking Apache for best results
	&& a2dismod mpm_event && a2enmod mpm_prefork \
	# PHP files should be handled by PHP, and should be preferred over any other file type
	&& { \
		echo '<FilesMatch \.php$>'; \
		echo '\tSetHandler application/x-httpd-php'; \
		echo '</FilesMatch>'; \
		echo; \
		echo 'DirectoryIndex disabled'; \
		echo 'DirectoryIndex index.php index.html'; \
		echo; \
		echo '<Directory /var/www/>'; \
		echo '\tOptions -Indexes'; \
		echo '\tAllowOverride All'; \
		echo '</Directory>'; \
	} | tee "$APACHE_CONFDIR/conf-available/docker-php.conf" \
	&& a2enconf docker-php \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends gnupg dirmngr; \
	rm -rf /var/lib/apt/lists/*; \
	\
	mkdir -p /usr/src; \
	cd /usr/src; \
	\
	curl -fsSL -o php.tar.xz "$PHP_URL"; \
	\
	if [ -n "$PHP_SHA256" ]; then \
		echo "$PHP_SHA256 *php.tar.xz" | sha256sum -c -; \
	fi; \
	if [ -n "$PHP_MD5" ]; then \
		echo "$PHP_MD5 *php.tar.xz" | md5sum -c -; \
	fi; \
	\
	if [ -n "$PHP_ASC_URL" ]; then \
		curl -fsSL -o php.tar.xz.asc "$PHP_ASC_URL"; \
		export GNUPGHOME="$(mktemp -d)"; \
		${IMAGES_DIR}/receiveGpgKeys.sh $GPG_KEYS; \
		gpg --batch --verify php.tar.xz.asc php.tar.xz; \
		gpgconf --kill all; \
		rm -rf "$GNUPGHOME"; \
	fi; \
	\
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark > /dev/null; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

COPY docker-php-source /usr/local/bin/

RUN set -eux; \
    \
	wget https://github.com/P-H-C/phc-winner-argon2/archive/20190702.tar.gz -O /tmp/argon2.tar.gz; \
	tar -xf /tmp/argon2.tar.gz; \
	ls -l; \
	cd phc-winner-argon2-20190702; \
	make; \
	make test; \
	make install PREFIX=/usr; \
	\
	wget http://ftp.us.debian.org/debian/pool/main/a/argon2/argon2_0~20171227-0.2_amd64.deb -O /tmp/argon2_0~20171227-0.2_amd64.deb \
	&& dpkg -i /tmp/argon2_0~20171227-0.2_amd64.deb; \
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
#		libargon2-0 \
		libcurl4-openssl-dev \
		libedit-dev \
		libonig-dev \
		libsodium-dev \
		libsqlite3-dev \
		libssl-dev \
		libxml2-dev \
		zlib1g-dev \
		${PHP_EXTRA_BUILD_DEPS:-} \
	; \
	rm -rf /var/lib/apt/lists/*; \
	\
	export \
		CFLAGS="$PHP_CFLAGS" \
		CPPFLAGS="$PHP_CPPFLAGS" \
		LDFLAGS="$PHP_LDFLAGS" \
	; \
	docker-php-source extract; \
	cd /usr/src/php; \
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
# https://bugs.php.net/bug.php?id=74125
	if [ ! -d /usr/include/curl ]; then \
		ln -sT "/usr/include/$debMultiarch/curl" /usr/local/include/curl; \
	fi; \
	./configure \
		--build="$gnuArch" \
		--with-config-file-path="$PHP_INI_DIR" \
		--with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
		\
		# make sure invalid --configure-flags are fatal errors intead of just warnings
		--enable-option-checking=fatal \
		\
		# https://github.com/docker-library/php/issues/439
		--with-mhash \
		\
		# --enable-ftp is included here because ftp_ssl_connect() needs ftp to be compiled statically (see https://github.com/docker-library/php/issues/236)
		--enable-ftp \
		# --enable-mbstring is included here because otherwise there's no way to get pecl to use it properly (see https://github.com/docker-library/php/issues/195)
		--enable-mbstring \
		# --enable-mysqlnd is included here because it's harder to compile after the fact than extensions are (since it's a plugin for several extensions, not an extension in itself)
		--enable-mysqlnd \
		# https://wiki.php.net/rfc/argon2_password_hash (7.2+)
		--with-password-argon2 \
		# https://wiki.php.net/rfc/libsodium
		--with-sodium=shared \
		# always build against system sqlite3 (https://github.com/php/php-src/commit/6083a387a81dbbd66d6316a3a12a63f06d5f7109)
		--with-pdo-sqlite=/usr \
		--with-sqlite3=/usr \
		\
		--with-curl \
		--with-libedit \
		--with-openssl \
		--with-zlib \
		\
		# in PHP 7.4+, the pecl/pear installers are officially deprecated (requiring an explicit "--with-pear") and will be removed in PHP 8+; see also https://github.com/docker-library/php/issues/846#issuecomment-505638494
		--with-pear \
		\
		# bundled pcre does not support JIT on s390x
		# https://manpages.debian.org/stretch/libpcre3-dev/pcrejit.3.en.html#AVAILABILITY_OF_JIT_SUPPORT
		$(test "$gnuArch" = 's390x-linux-gnu' && echo '--without-pcre-jit') \
		--with-libdir="lib/$debMultiarch" \
		\
		${PHP_EXTRA_CONFIGURE_ARGS:-} \
	; \
	make -j "$(nproc)"; \
	find -type f -name '*.a' -delete; \
	make install; \
	find /usr/local/bin /usr/local/sbin -type f -executable -exec strip --strip-all '{}' + || true; \
	make clean; \
	\
	# https://github.com/docker-library/php/issues/692 (copy default example "php.ini" files somewhere easily discoverable)
	cp -v php.ini-* "$PHP_INI_DIR/"; \
	\
	cd /; \
	docker-php-source delete; \
	\
	# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
	find /usr/local -type f -executable -exec ldd '{}' ';' \
		| awk '/=>/ { print $(NF-1) }' \
		| sort -u \
		| xargs -r dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| xargs -r apt-mark manual \
	; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	\
	# update pecl channel definitions https://github.com/docker-library/php/issues/443
	pecl update-channels; \
	rm -rf /tmp/pear ~/.pearrc; \
	# smoke test
	php --version

COPY docker-php-ext-* docker-php-entrypoint /usr/local/bin/

# sodium was built as a shared module (so that it can be replaced later if so desired), so let's enable it too (https://github.com/docker-library/php/issues/598)
RUN docker-php-ext-enable sodium

ENTRYPOINT ["docker-php-entrypoint"]
##<autogenerated>##
# https://httpd.apache.org/docs/2.4/stopping.html#gracefulstop
STOPSIGNAL SIGWINCH

COPY apache2-foreground /usr/local/bin/
WORKDIR /var/www/html

EXPOSE 80
CMD ["apache2-foreground"]
##</autogenerated>##
