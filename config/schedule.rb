# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
 set :output, "/home/ubuntu/groove/log/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

# set :output, Rails.root.join('log', 'cron.log')

every 10.minutes do # 1.minute 1.day 1.week 1.month 1.year is also supported
  rake "ftp_csv_file_import:ftp_import"
end

every 5.minutes do # 1.minute 1.day 1.week 1.month 1.year is also supported
  rake "doo:check_failed_or_stopped_jobs"
end

every 5.minutes do # 1.minute 1.day 1.week 1.month 1.year is also supported
  rake "delayed_job:restart_workers"
end

every '*/5 5-12,0 * * *' do # 1.minute 1.day 1.week 1.month 1.year is also supported
  rake "check:umi_import"
end

every 10.minutes do # 1.minute 1.day 1.week 1.month 1.year is also supported
  if environment=='staging'
    command "/home/ubuntu/groove/scripts-staging/meganto_status_update.sh"
  else
    command "/home/ubuntu/groove/meganto_status_update.sh"
  end
end

every 1.day, :at => '7:40 am' do
  rake "doo:schedule_inventory_email"
end

every 1.day, :at => '7:50 am' do
  rake "doo:schedule_orders_export_email"
end

every 1.day, :at => '12:00 am' do
  rake "doo:delete_old_orders"
end

every 60.minutes  do
  rake "doo:schedule_hourly_import"
end

every 1.day, :at => '03:00 am' do
  rake "doo:schedule_inventory_report"
end
# every 1.day, :at => '03:00 am' do
#   runner "backup perform --trigger db_backup"
# end

# every :tuesday, :at => '01:01 am' do
#   command "backup perform --trigger db_backup"
# end
