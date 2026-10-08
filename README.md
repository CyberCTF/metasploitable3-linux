# Metasploitable 3 (Linux)

[Metasploitable 3](https://github.com/rapid7/metasploitable3) by Rapid7: an intentionally
vulnerable server for practising exploitation. This repository runs its Ubuntu 14.04 machine with
[Isoloom](https://www.isoloom.com): [`isoloom.yml`](isoloom.yml) describes the machine, and
upstream's own Chef cookbooks (vendored unchanged in [`metasploitable3/`](metasploitable3)) build
it inside the VM, with the run list of upstream's Packer template
([`provision/build.sh`](provision/build.sh)).

| Machine | Services |
| --- | --- |
| ub1404 | FTP 21 (ProFTPD 1.3.5), SSH 22, HTTP 80 (Drupal 7.5, phpMyAdmin 3.5.8, payroll app), Samba 445, CUPS 631, MySQL 3306, readme app 3500, UnrealIRCd 6697, Apache Continuum 8080, Sinatra 8181 |

## Run it

```bash
isoloom run vagrant
isoloom test vagrant
```

VirtualBox only (the `ubuntu/trusty64` base box has no other provider). The first build takes
about half an hour: Chef compiles PHP 5.4.5, ProFTPD and UnrealIRCd from source and downloads the
historical releases upstream pins. About 4 GB of memory (3 GB for the machine, as the build
runs out of memory at 2 GB, and 1 GB for the controller that runs the checks).

Differences from upstream's own build, all forced by what still works today:

- Upstream builds a box from the Ubuntu 14.04.0 ISO with Packer; here the base is the
  `ubuntu/trusty64` box (Ubuntu 14.04.6) and the same cookbooks run on it.
- Upstream pins Chef 13.8.5, which Chef no longer distributes without a licence; the cookbooks run
  on [Cinc Client](https://cinc.sh) 15.2.20, the open-source build of Chef, pinned by checksum.
- APT on Ubuntu 14.04 (GnuTLS 2.12) can no longer reach download.docker.com, which upstream's
  docker recipe uses: a local stunnel relay stands in while Chef runs, then is removed
  ([`provision/docker-apt-relay.sh`](provision/docker-apt-relay.sh)).
- The docker cookbook's `docker-api` gem now resolves to excon 0.109, which can't parse Docker
  18.06's answers: docker-api 1.34.2, excon 0.62.0 and multi_json 1.13.1 are installed first and
  served to Chef from a local gem server during the run.
- Upstream's readme app and Sinatra app run `bundle install` each time they start, which today
  never finishes (Bundler 1.3.5 downloads rubygems.org's whole legacy index), and the Sinatra
  Gemfile is unpinned, so it now resolves to gems Ruby 2.3 can't run. Their gems are installed at
  fixed versions from checksummed .gem files, with a Gemfile.lock for Sinatra dated like its
  Gemfile ([`provision/ruby-apps.sh`](provision/ruby-apps.sh)).
- The machine reboots once at the end of the build, as upstream's box boots fresh after Packer.

Lab guide: the [Metasploitable 3 wiki](https://github.com/rapid7/metasploitable3/wiki).
Upstream version and commit: [UPSTREAM.md](UPSTREAM.md).

## Licence

BSD-3-Clause, as Metasploitable 3 ([LICENSE](LICENSE), [COPYING](COPYING)), copyright Rapid7.

Notice: the machine installs third-party software that keeps its own licences, not BSD-3-Clause:
among others Drupal, phpMyAdmin, PHP, ProFTPD, UnrealIRCd, Apache Continuum, Samba, CUPS, MySQL
and Docker (GPL, Apache-2.0, PHP and other licences), downloaded from their historical release
archives at build time. The Windows-only resources in `metasploitable3/resources/` (Jenkins and
others) are listed with their licences in upstream's [LICENSE](LICENSE). This machine is
deliberately vulnerable: keep it isolated.
