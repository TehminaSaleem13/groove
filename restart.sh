#!/bin/sh

sudo chown groovepacker:groovepacker /home/groovepacker/groove -R

sudo su groovepacker <<'EOF'
source /usr/local/rvm/scripts/rvm

cd ~/groove
git remote set-url origin git@bitbucket.org:jonnyclean/groovepacker.git

git pull origin master

RAILS_ENV=production bundle install --deployment
RAILS_ENV=production rake db:migrate
RAILS_ENV=production rake assets:precompile

exit
EOF

sudo service nginx restart
