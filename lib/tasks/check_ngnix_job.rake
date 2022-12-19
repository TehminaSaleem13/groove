# frozen_string_literal: true

namespace :doo do
  desc 'Check the jobs and restart'
  task check_nginx_process: :environment do
    `sudo service nginx restart`
  end
end
