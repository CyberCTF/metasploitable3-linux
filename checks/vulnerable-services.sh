#!/bin/sh
# Metasploitable 3's own applications answer: the Drupal 7.5 site, phpMyAdmin 3.5.8, the payroll
# app, the readme Rails app and the Sinatra app; UnrealIRCd shows its 3.2.8.1 banner.
set -u
ok() { curl -sS --max-time 20 "$1" 2>/dev/null | grep -qi "$2"; }
ok http://ub1404/drupal/ "drupal" || { echo "drupal"; exit 1; }
ok http://ub1404/phpmyadmin/ "phpmyadmin" || { echo "phpmyadmin"; exit 1; }
ok http://ub1404/payroll_app.php "payroll\|user" || { echo "payroll app"; exit 1; }
ok http://ub1404:3500/ "readme\|rails\|html" || { echo "readme app"; exit 1; }
[ "$(curl -s -o /dev/null --max-time 20 -w '%{http_code}' http://ub1404:8181/)" != 000 ] || { echo "sinatra"; exit 1; }
echo "Drupal, phpMyAdmin, payroll, readme and Sinatra apps answer"
