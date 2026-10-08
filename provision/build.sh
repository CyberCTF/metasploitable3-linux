#!/bin/sh
# Builds Metasploitable 3 (Ubuntu 14.04) inside the VM with upstream's own Chef cookbooks, the
# run list of upstream's Packer template (packer/templates/ubuntu_1404.json), unchanged.
# Differences from upstream's Packer build, and why:
# - Chef 13.8.5 (upstream's pin) is no longer downloadable (packages.chef.io answers 402), so
#   the cookbooks run on Cinc Client 15.2.20, the open-source build of Chef, the newest one
#   published for Ubuntu 14.04. Pinned by version and SHA-256.
# - APT on 14.04 can't reach download.docker.com over HTTPS any more: a local relay stands in
#   while Chef runs (provision/docker-apt-relay.sh).
# - Upstream's docker cookbook asks for the docker-api gem (~> 1.34.0), and Chef resolves its
#   dependencies from rubygems.org today: excon 0.109, whose parser rejects Docker 18.06's
#   answers ("malformed header"). The gems are installed here at versions of the cookbook's
#   time (docker-api 1.34.2, excon 0.62.0, multi_json 1.13.1) and Chef resolves them from a
#   local gem server for the run, so nothing newer is pulled.
# - Upstream's two Ruby apps can't install their gems at start any more: provision/ruby-apps.sh.
# - Upstream builds the box from the Ubuntu 14.04.0 ISO with Packer; here the base is the
#   ubuntu/trusty64 Vagrant box (Ubuntu 14.04.6), and Chef runs on it as a provisioning step.
set -eu
export DEBIAN_FRONTEND=noninteractive
SRC=/opt/isoloom/metasploitable3
CINC_URL=https://packages.cinc.sh/files/stable/cinc/15.2.20/ubuntu/14.04/cinc_15.2.20-1_amd64.deb
CINC_SHA256=d7391e9380752b75de842a888353a8e52fcdc1c108277bc70fe8f4caf4eb5c4d

if [ -f /etc/metasploitable3-built ]; then echo "already built"; exit 0; fi

if ! command -v cinc-solo >/dev/null 2>&1; then
  wget -q -O /tmp/cinc.deb "$CINC_URL"
  echo "$CINC_SHA256  /tmp/cinc.deb" | sha256sum -c -
  dpkg -i /tmp/cinc.deb
  rm -f /tmp/cinc.deb
fi

G=/opt/cinc/embedded/bin/gem
for g in excon:0.62.0 multi_json:1.13.1; do
  $G list -i "${g%%:*}" -v "${g#*:}" >/dev/null || $G install "${g%%:*}" -v "${g#*:}" --no-document
done
$G list -i docker-api -v 1.34.2 >/dev/null || $G install docker-api -v 1.34.2 --ignore-dependencies --no-document

# Upstream's attributes name the files folder under /vagrant (where its Vagrant box was built).
[ -e /vagrant ] || ln -s "$SRC" /vagrant

mkdir -p /var/chef-solo
cat > /var/chef-solo/solo.rb <<SOLO
cookbook_path ["$SRC/chef/cookbooks"]
file_cache_path "/var/chef-solo/cache"
trusted_certs_dir "/etc/cinc/trusted_certs"
rubygems_url "http://127.0.0.1:8808"
SOLO

RUN_LIST="apt::default,metasploitable::users,metasploitable::mysql,metasploitable::apache_continuum,metasploitable::apache,metasploitable::php_545,metasploitable::phpmyadmin,metasploitable::proftpd,metasploitable::docker,metasploitable::samba,metasploitable::sinatra,metasploitable::unrealircd,metasploitable::chatbot,metasploitable::payroll_app,metasploitable::readme_app,metasploitable::cups,metasploitable::drupal,metasploitable::knockd,metasploitable::iptables,metasploitable::flags,metasploitable::ifnames"
sh /opt/isoloom/provision/docker-apt-relay.sh start
$G server --bind 127.0.0.1 --port 8808 >/var/log/gem-server.log 2>&1 &
gems=$!
sleep 5
status=0
cinc-solo -c /var/chef-solo/solo.rb -o "$RUN_LIST" --no-color || status=$?
kill "$gems" || true
sh /opt/isoloom/provision/docker-apt-relay.sh stop
[ "$status" -eq 0 ] || exit "$status"

sh /opt/isoloom/provision/ruby-apps.sh

touch /etc/metasploitable3-built
# Upstream's box boots fresh after the build, which is what starts every service cleanly (the
# ones Chef starts die with the provisioning session): reboot once, in the background.
nohup setsid sh -c 'sleep 5; reboot' >/dev/null 2>&1 &
