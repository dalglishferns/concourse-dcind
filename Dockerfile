FROM alpine:3.18

ENV DOCKER_CHANNEL=stable \
  DOCKER_VERSION=24.0.5 \
  DOCKER_COMPOSE_VERSION=2.22.0

RUN apk update \
  && apk add --no-cache bash curl iptables ca-certificates make net-tools iproute2 pigz \
  && curl -fL "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/x86_64/docker-${DOCKER_VERSION}.tgz" | tar zx \
  && mv /docker/* /usr/bin/ \
  && chmod +x /usr/bin/docker* \
  && curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-linux-$(uname -m)" -o /usr/bin/docker-compose \
  && chmod +x /usr/bin/docker-compose \
  && rm -rf /var/cache/apk/*

WORKDIR /shared

COPY entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]
