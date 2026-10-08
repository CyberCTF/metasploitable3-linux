#!/bin/sh
# Ubuntu 14.04's APT fetches HTTPS with GnuTLS 2.12, which can no longer complete a handshake
# with download.docker.com ("gnutls_handshake() failed: A TLS packet with unexpected length").
# Upstream's docker recipe adds that repository, so during the build download.docker.com points
# at a local stunnel relay: APT talks to the relay, the relay talks to the real host with
# OpenSSL (which still can). `docker-apt-relay.sh start` before Chef, `stop` after it.
set -eu
HOST=download.docker.com
DIR=/etc/stunnel/docker-relay
case "$1" in
start)
  apt-get install -y -q stunnel4 >/dev/null
  ip=$(getent ahostsv4 "$HOST" | awk 'NR==1 { print $1 }')
  mkdir -p "$DIR" /etc/cinc/trusted_certs
  [ -f "$DIR/relay.pem" ] || openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -subj "/CN=$HOST" -keyout "$DIR/relay.pem" -out "$DIR/relay.crt" 2>/dev/null
  cat "$DIR/relay.crt" >> "$DIR/relay.pem"
  chmod 600 "$DIR/relay.pem"
  cp "$DIR/relay.crt" /usr/local/share/ca-certificates/docker-relay.crt
  update-ca-certificates >/dev/null
  cp "$DIR/relay.crt" /etc/cinc/trusted_certs/docker-relay.crt
  cat > "$DIR/relay.conf" <<CONF
pid = /var/run/docker-relay.pid
[in]
accept = 127.0.0.1:443
cert = $DIR/relay.pem
connect = 127.0.0.1:8443
[out]
client = yes
sslVersion = all
accept = 127.0.0.1:8443
connect = $ip:443
sni = $HOST
CONF
  stunnel4 "$DIR/relay.conf"
  grep -q " $HOST\$" /etc/hosts || echo "127.0.0.1 $HOST" >> /etc/hosts
  ;;
stop)
  [ -f /var/run/docker-relay.pid ] && kill "$(cat /var/run/docker-relay.pid)" || true
  sed -i "/ $HOST\$/d" /etc/hosts
  rm -f /usr/local/share/ca-certificates/docker-relay.crt /etc/cinc/trusted_certs/docker-relay.crt
  update-ca-certificates --fresh >/dev/null
  rm -rf "$DIR"
  ;;
esac
