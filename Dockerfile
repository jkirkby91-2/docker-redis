FROM jkirkby91/ubuntusrvbase:latest

MAINTAINER James Kirkby <jkirkby91@gmail.com>

RUN groupadd -r redis && useradd -r -g redis redis

# Install packages specific to our project
RUN apt-get update && \
apt-get upgrade -y && \
apt-get install -y wget gcc libc6-dev make --force-yes --fix-missing

# grab gosu for easy step-down from root
ENV GOSU_VERSION 1.7

RUN set -x \
	&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
	&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
	&& gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
	&& rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu \
	&& gosu nobody true

ENV REDIS_VERSION 3.0.7

ENV REDIS_DOWNLOAD_URL http://download.redis.io/releases/redis-3.0.7.tar.gz

ENV REDIS_DOWNLOAD_SHA1 e56b4b7e033ae8dbf311f9191cf6fdf3ae974d1c

# for redis-sentinel see: http://redis.io/topics/sentinel
RUN wget -O redis.tar.gz "$REDIS_DOWNLOAD_URL" \
	&& echo "$REDIS_DOWNLOAD_SHA1 *redis.tar.gz" | sha1sum -c - \
	&& mkdir -p /usr/src/redis \
	&& tar -xzf redis.tar.gz -C /usr/src/redis --strip-components=1 \
	&& rm redis.tar.gz \
	&& make -C /usr/src/redis \
	&& make -C /usr/src/redis install \
	&& rm -r /usr/src/redis && \
	apt-get remove --purge -y software-properties-common build-essential && \
	apt-get autoremove -y && \
	apt-get clean && \
	apt-get autoclean && \
	echo -n > /var/lib/apt/extended_states && \
	rm -rf /var/lib/apt/lists/* && \
	rm -rf /usr/share/man/?? && \
	rm -rf /usr/share/man/??_*

RUN mkdir /data && chown redis:redis /data

VOLUME /data

WORKDIR /data

COPY docker-entrypoint.sh /usr/local/bin/

COPY confs/apparmor/redis.conf /etc/apparmor/redis.conf

COPY docker-entrypoint.sh /usr/local/bin/

RUN ln -s usr/local/bin/docker-entrypoint.sh /entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 6379

COPY start.sh /start.sh

RUN chmod 777 /start.sh

COPY confs/supervisord/supervisord.conf /etc/supervisord.conf

CMD ["/bin/bash", "/start.sh"]
