#!/bin/bash
cd /home/ubuntu/groove
source /home/ubuntu/.rvm/scripts/rvm              #for production
rvm use ruby-2.4.0                                                 #for production
RAILS_ENV=staging bundle exec rake doo:upload_magento_order_tracking_info
