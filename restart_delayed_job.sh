#!/bin/sh

sudo chown groovepacker:groovepacker /home/groovepacker/groove -R

sudo su groovepacker <<'EOF'
source /usr/local/rvm/scripts/rvm

cd ~/groove

RAILS_ENV=production script/delayed_job stop
RAILS_ENV=production script/delayed_job start

exit
EOF