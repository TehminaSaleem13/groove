#!/bin/sh

sudo su groovepacker <<'EOF'
cd ~/groove
git pull origin master
exit
EOF

RAILS_ENV=production rvmsudo bundle install

RAILS_ENV=production rvmsudo rake db:migrate
RAILS_ENV=production rvmsudo rake assets:precompile

sudo service nginx restart
