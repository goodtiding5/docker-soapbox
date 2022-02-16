FROM elixir:1.13-alpine as build

ARG RELEASE_TAG="latest"
ARG MIX_ENV=prod

RUN apk --update add --no-cache git gcc g++ musl-dev make cmake file-dev \
&&  git clone https://gitlab.com/soapbox-pub/soapbox.git /pleroma \
&&  cd /pleroma \
&&  echo "import Mix.Config" > config/prod.secret.exs \
&&  mix local.hex --force \
&&  mix local.rebar --force \
&&  mix deps.get --only prod \
&&  mkdir -p /release \
&&  mix release --path /release

# -------------------------------------------------------------------------------------------------------

FROM alpine:3

LABEL maintainer="ken@epenguin.com"

ARG UID=1000
ARG GID=1000
ARG HOME=/opt/pleroma
ARG DATA=/var/lib/pleroma

ENV DOMAIN=localhost \
    INSTANCE_NAME="Pleroma" \
    ADMIN_EMAIL="admin@localhost" \
    NOTIFY_EMAIL="info@localhost" \
    DB_HOST="db" \
    DB_NAME="pleroma" \
    DB_USER="pleroma" \
    DB_PASS="pleroma"

RUN set -eux \
&&  apk --update add --no-cache \
        tini \
	curl \
	su-exec \
	ncurses \
	postgresql-client \
	imagemagick \
	ffmpeg \
	exiftool \
	libmagic \
&&  addgroup --gid "$GID" pleroma \
&&  adduser --disabled-password --gecos "Pleroma" --home "$HOME" --ingroup pleroma --uid "$UID" pleroma \
&&  mkdir -p ${HOME} ${DATA}/uploads ${DATA}/static \
&&  chown -R pleroma:pleroma ${HOME} ${DATA} \
&&  mkdir -p /etc/pleroma \
&&  chown -R pleroma:root /etc/pleroma

COPY --from=build --chown=pleroma:0 /release ${HOME}
COPY --from=build --chown=pleroma:0 /pleroma/config/docker.exs /etc/pleroma/config.exs

COPY ./bin /usr/local/bin
COPY ./entrypoint.sh /entrypoint.sh

RUN set -eux \
&&  curl -L https://gitlab.com/soapbox-pub/soapbox-fe/-/jobs/artifacts/v1.3.0/download?job=build-production -o /tmp/soapbox-fe.zip \
&&  busybox unzip /tmp/soapbox-fe.zip -o -d /opt/pleroma/instance \
&&  rm -f /tmp/soapbox-fe.zip

VOLUME $DATA

EXPOSE 4000

STOPSIGNAL SIGTERM

HEALTHCHECK \
    --start-period=10m \
    --interval=5m \ 
    CMD curl --fail http://localhost:4000/api/v1/instance || exit 1

ENTRYPOINT ["tini", "--", "/entrypoint.sh"]
