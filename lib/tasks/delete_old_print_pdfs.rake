# frozen_string_literal: true

namespace :doo do
    desc 'Delete Pdfs earlier than 3 days'
  
    task delete_print_pdfs: :environment do
      next if $redis.get('delete_pdfs_earlier_than_3_days')

      $redis.set('delete_pdfs_earlier_than_3_days', true)
      $redis.expire('delete_pdfs_earlier_than_3_days', 180)
      tenants = Tenant.all
      tenants.find_each do |tenant|
        Apartment::Tenant.switch! tenant.name
        PrintPdfLink.where('created_at <= ?', 3.days.ago).each do |link|
            GroovS3.delete_object(link.url.gsub("#{ENV['S3_BASE_URL']}/", ''))
            link.destroy
        end
      end
    end
  end

  #PrintPdfLink.where(created_at: Date.today.beginning_of_day..Date.today.end_of_day).each