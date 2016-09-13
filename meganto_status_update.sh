#!/bin/bash
cd /home/ubuntu/groove
source /home/ubuntu/.rvm/scripts/rvm              #for production
rvm use ruby-2.0.0-p643                                                 #for production
RAILS_ENV=production bundle exec rake doo:upload_magento_order_tracking_info