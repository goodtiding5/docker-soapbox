# -------------------------------------------------------------------------------------------------------

FROM elixir:1.12-alpine as build

ARG RELEASE_TAG="latest"
ARG MIX_ENV=prod

RUN set -ex \
&&  apk --update add --no-cache git gcc g++ musl-dev make cmake file-dev \
&&  git clone https://gitlab.com/soapbox-pub/rebased.git /pleroma \
&&  git clone https://github.com/facebookresearch/fastText.git /fastText

## build rebase

WORKDIR /pleroma

ENV MIX_ENV=${MIX_ENV}

# setup elixir environment
RUN set -ex \
&&  echo "import Mix.Config" > config/prod.secret.exs \
&&  mix local.hex --force \
&&  mix local.rebar --force

# build soapbox/rebase into the relase dir
RUN mix deps.get --only prod \
&&  mkdir -p /release \
&&  mix release --path /release

## build fasttext

WORKDIR /fastText

RUN set -ex \
&&  make \
&&  mkdir -p /dist \
&&  cp fasttext /dist

# -------------------------------------------------------------------------------------------------------

FROM alpine:3.16

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
&&  curl -L "https://gitlab.com/soapbox-pub/soapbox-fe/-/jobs/artifacts/develop/download?job=build-production" -o /tmp/soapbox-fe.zip \
&&  unzip -o /tmp/soapbox-fe.zip -d ${DATA} \
&&  rm -f /tmp/soapbox-fe.zip \
&&  chown -R pleroma:pleroma ${HOME} ${DATA} \
&&  mkdir -p /etc/pleroma \
&&  chown -R pleroma:root /etc/pleroma

COPY --from=build --chown=0:0 /dist/fasttext /usr/local/bin
COPY --from=build --chown=pleroma:0 /release ${HOME}
COPY --from=build --chown=pleroma:0 /pleroma/config/docker.exs /etc/pleroma/config.exs

COPY ./bin /usr/local/bin
COPY ./entrypoint.sh /entrypoint.sh

VOLUME $DATA

EXPOSE 5000

STOPSIGNAL SIGTERM

HEALTHCHECK \
    --start-period=10m \
    --interval=5m \ 
    CMD curl --fail http://localhost:5000/api/v1/instance || exit 1

USER pleroma

ENTRYPOINT ["tini", "--", "/entrypoint.sh"]

