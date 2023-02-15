#!/bin/sh

set -e

WORKDIR=/opt/pleroma
DATADIR=/var/lib/pleroma

#SOAPBOX="https://gitlab.com/soapbox-pub/soapbox/-/jobs/artifacts/develop/download?job=build-production"
SOAPBOX="https://gitlab.com/soapbox-pub/soapbox/-/jobs/artifacts/v3.2.0/download?job=build-production"

echo "-- Waiting for database..."
while ! pg_isready -U ${DB_USER:-pleroma} -d postgres://${DB_HOST:-db}:5432/${DB_NAME:-pleroma} -t 1; do
    sleep 1s
done


echo "-- Updating FE..."

# Download the build.
curl -L "$SOAPBOX"  -o /tmp/soapbox-fe.zip

# Remove all the current Soapbox build in Pleroma's instance directory.
rm -fR ${DATADIR}/static/packs
rm -f  ${DATADIR}/static/index.html
rm -fR ${DATADIR}/static/sounds

# Unzip the new build to Pleroma's instance directory.
unzip -o /tmp/soapbox-fe.zip -d ${DATADIR}

# Cleanup
rm -f /tmp/soapbox-fe.zip

echo "-- Running migrations..."
$WORKDIR/bin/pleroma_ctl migrate

echo "-- Starting!"
exec $WORKDIR/bin/pleroma start
