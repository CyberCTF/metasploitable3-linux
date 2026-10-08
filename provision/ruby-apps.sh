#!/bin/sh
# Upstream's two Ruby apps run `bundle install` each time they start (Bundler 1.3.5, Ruby 2.3).
# Today that downloads rubygems.org's whole legacy index for minutes, and the Sinatra app's
# Gemfile has no lock and unpinned gems, which now resolve to versions Ruby 2.3 can't run, so
# neither app ever answers. Their gems are installed here at fixed versions (the readme app's own
# Gemfile.lock; the Sinatra app's at its Gemfile's date, with a Gemfile.lock next to it), from
# .gem files checked by SHA-256, so the start-time `bundle install` finds everything locally.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
CACHE=/var/cache/metasploitable3-gems
mkdir -p "$CACHE"
fetch() { # list -> downloads every gem of the list into the cache, checked
  grep -v '^#' "$1" | while read -r n v sha; do
    f="$CACHE/$n-$v.gem"
    [ -f "$f" ] || wget -q --no-check-certificate -O "$f" "https://rubygems.org/downloads/$n-$v.gem"
    echo "$sha  $f" | sha256sum -c --quiet -
  done
}
install_list() { # list, extra gem install arguments...
  list=$1; shift
  grep -v '^#' "$list" | while read -r n v sha; do
    gem install --local --ignore-dependencies --no-document "$@" "$CACHE/$n-$v.gem" >/dev/null
  done
}
apt-get install -y -q libxml2-dev libxslt1-dev zlib1g-dev libsqlite3-dev >/dev/null
export NOKOGIRI_USE_SYSTEM_LIBRARIES=1

# Sinatra (runs as root from /opt/sinatra).
fetch "$HERE/gems/sinatra.txt"
install_list "$HERE/gems/sinatra.txt"
cp "$HERE/gems/sinatra.Gemfile.lock" /opt/sinatra/Gemfile.lock
(cd /opt/sinatra && bundle install --local >/dev/null)

# The readme app (runs as chewbacca, gems under its vendor/bundle).
fetch "$HERE/gems/readme_app.txt"
chmod 0755 "$CACHE"; chmod 0644 "$CACHE"/*.gem
dir=/opt/readme_app/vendor/bundle/ruby/2.3.0
sudo -u chewbacca -H mkdir -p "$dir"
grep -v '^#' "$HERE/gems/readme_app.txt" | while read -r n v sha; do
  sudo -u chewbacca -H env NOKOGIRI_USE_SYSTEM_LIBRARIES=1 GEM_HOME="$dir" \
    gem install --local --ignore-dependencies --no-document -i "$dir" "$CACHE/$n-$v.gem" >/dev/null
done
sudo -u chewbacca -H sh -c 'cd /opt/readme_app && bundle install --path vendor/bundle --local >/dev/null'
echo "Ruby apps' gems installed"
