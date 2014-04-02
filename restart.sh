#!/bin/sh

sudo su groovepacker <<'EOF'
cd ~/groove
git pull origin master
exit
EOF
cd /home/groovepacker/groove
rvmsudo bundle install RAILS_ENV=production

rvmsudo rake db:migrate RAILS_ENV=production
rvmsudo rake assets:precompile RAILS_ENV=production

sudo service nginx restart

cd -
