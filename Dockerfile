FROM debian:jessie
# MAINTAINER Peter T Bosse II <ptb@ioutime.com>

RUN \
  REQUIRED_PACKAGES="libxml2-dev libxslt-dev python" \
  && BUILD_PACKAGES="build-essential libffi-dev libssl-dev python-dev wget" \

  && USERID_ON_HOST=1026 \

  && useradd \
    --comment CouchPotato \
    --create-home \
    --gid users \
    --no-user-group \
    --shell /usr/sbin/nologin \
    --uid $USERID_ON_HOST \
    couchpotato \

  && echo "debconf debconf/frontend select noninteractive" \
    | debconf-set-selections \

  && sed \
    -e "s/httpredir.debian.org/debian.mirror.constant.com/" \
    -i /etc/apt/sources.list \

  && apt-get update -qq \
  && apt-get install -qqy \
    $REQUIRED_PACKAGES \
    $BUILD_PACKAGES \

  && mkdir -p /app/ \
  && wget \
    --output-document - \
    --quiet \
    https://api.github.com/repos/RuudBurger/CouchPotatoServer/tarball/master \
    | tar -xz -C /app/ \
  && mv /app/RuudBurger-CouchPotatoServer* /app/couchpotato \
  && chown -R couchpotato:users /app/couchpotato/ \
  && find /app/couchpotato -name "*.py" -print0 \
    | xargs -0 chmod +x \

  && wget \
    --output-document - \
    --quiet \
    https://api.github.com/repos/just-containers/s6-overlay/releases/latest \
    | sed -n "s/^.*browser_download_url.*: \"\(.*s6-overlay-amd64.tar.gz\)\".*/\1/p" \
    | wget \
      --input-file - \
      --output-document - \
      --quiet \
    | tar -xz -C / \

  && mkdir -p /etc/services.d/couchpotato/ \
  && printf "%s\n" \
    "#!/usr/bin/env sh" \
    "set -ex" \
    "exec s6-applyuidgid -g 100 -u $USERID_ON_HOST \\" \
    "  /app/couchpotato/CouchPotato.py \\" \
    "  --config_file=/home/couchpotato/config.ini \\" \
    "  --data_dir=/home/couchpotato" \
    > /etc/services.d/couchpotato/run \
  && chmod +x /etc/services.d/couchpotato/run \

  && mkdir -p /app/ffmpeg/ \
  && wget \
    --output-document - \
    --quiet \
    http://cdn.ptb2.me/ffmpeg-2.8.2.tar.gz \
    | tar -xz -C /app/ffmpeg/ \

  && wget \
    --output-document - \
    --quiet \
    https://bootstrap.pypa.io/ez_setup.py \
    | python \
  && wget \
    --output-document - \
    --quiet \
    https://raw.github.com/pypa/pip/master/contrib/get-pip.py \
    | python \
  && pip install \
    babelfish \
    'guessit<2' \
    lxml \
    qtfaststart \
    requests \
    subliminal \
  && pip install \
    requests[security] \
  && pip install --upgrade \
    pyopenssl \

  && wget \
    --output-document - \
    --quiet \
    https://api.github.com/repos/mdhiggins/sickbeard_mp4_automator/tarball/master \
    | tar -xz -C /app/ \
  && mv /app/mdhiggins-sickbeard_mp4_automator* /app/mkv-to-m4v \
  && sed -e '/if self.original/,+3 d' -i /app/mkv-to-m4v/tmdb_mp4.py \
  && sed -e '/if self.original/,+3 d' -i /app/mkv-to-m4v/tvdb_mp4.py \
  && chown -R couchpotato:users /app/mkv-to-m4v/ \
  && find /app/mkv-to-m4v -name "*.py" -print0 \
    | xargs -0 chmod +x \

  && apt-get purge -qqy --auto-remove \
    $BUILD_PACKAGES \
  && apt-get clean -qqy \
  && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

ENTRYPOINT ["/init"]
EXPOSE 5050

# docker build --rm --tag ptb2/couchpotato .
# docker run --detach --name couchpotato --net host \
#   --publish 5050:5050/tcp \
#   --volume /volume1/@appstore/CouchPotato:/home/couchpotato \
#   --volume /volume1/@appstore/mkv-to-m4v/autoProcess.ini:/app/mkv-to-m4v/autoProcess.ini \
#   --volume /volume1/Incoming:/home/media \
#   ptb2/couchpotato
