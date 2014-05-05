#!/bin/sh

sudo su groovepacker <<'EOF'
cd ~/groove
git pull origin master
exit
EOF
cd /home/groovepacker/groove
RAILS_ENV=production rvmsudo bundle install

rvmsudo rake db:migrate RAILS_ENV=production
rvmsudo rake assets:precompile RAILS_ENV=production

sudo service nginx restart

cd -