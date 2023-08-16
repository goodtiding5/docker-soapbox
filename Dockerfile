# -------------------------------------------------------------------------------------------------------

FROM elixir:1.11-alpine as build

ARG MIX_ENV=prod

RUN set -ex \
&&  awk 'NR==2' /etc/apk/repositories | sed 's/main/community/' | tee -a /etc/apk/repositories \
&&  apk --update add --no-cache git gcc g++ musl-dev make cmake file-dev \
&&  git clone -b develop https://gitlab.com/goodtiding5/rebased.git /pleroma \
&&  git clone https://github.com/facebookresearch/fastText.git /fastText

## building rebase

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

## building fasttext

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

ADD https://dl.fbaipublicfiles.com/fasttext/supervised-models/lid.176.ftz /usr/share/fasttext/

RUN set -eux \
&&  awk 'NR==2' /etc/apk/repositories | sed 's/main/community/' | tee -a /etc/apk/repositories \
&&  apk --update add --no-cache \
	curl \
	unzip \
	su-exec \
	ncurses \
	postgresql-client \
	postgresql-contrib \
	imagemagick \
	ffmpeg \
	exiftool \
	libmagic \
	file-dev \
&&  addgroup --gid "$GID" pleroma \
&&  adduser --disabled-password --gecos "Pleroma" --home "$HOME" --ingroup pleroma --uid "$UID" pleroma \
&&  mkdir -p ${HOME} ${DATA}/uploads ${DATA}/static \
&&  chown -R pleroma:pleroma ${HOME} ${DATA} \
&&  mkdir -p /etc/pleroma \
&&  chown -R pleroma:root /etc/pleroma \
&&  chmod 0644 /usr/share/fasttext/lid.176.ftz 

COPY --from=build --chown=0:0 /dist/fasttext /usr/local/bin
COPY --from=build --chown=pleroma:0 /release ${HOME}
COPY --from=build --chown=pleroma:0 --chmod o= /pleroma/config/docker.exs /etc/pleroma/config.exs

COPY ./bin /usr/local/bin
COPY --chmod=0555 /entrypoint.sh /entrypoint.sh

VOLUME $DATA

EXPOSE 5000

STOPSIGNAL SIGTERM

HEALTHCHECK \
    --start-period=10m \
    --interval=5m \ 
    CMD curl --fail http://localhost:5000/api/v1/instance || exit 1

USER pleroma

ENTRYPOINT ["/entrypoint.sh"]

