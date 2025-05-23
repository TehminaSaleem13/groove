# frozen_string_literal: true

class Tenant < ApplicationRecord
  store :settings, accessors: %i[mark_discrepancies_scanned], coder: JSON

  after_initialize :initialize_default_settings, if: :new_record?

  validates :name, uniqueness: true
  has_one :subscription
  has_one :access_restriction
  serialize :price
  before_destroy :remove_subscriber_from_campaignmonitor
  after_destroy :delete_delayed_jobs

  def remove_subscriber_from_campaignmonitor
    initialize_campaingmonitor.remove_subscriber_from_lists
  end

  def delete_delayed_jobs
    Delayed::Job.where(tenant: name).delete_all
  end

  def initialize_campaingmonitor
    @cm ||= Groovepacker::CampaignMonitor::CampaignMonitor.new(subscriber: subscription)
  end

  def self.save_se_import_data(*data)
    return unless Tenant.find_by_name(Apartment::Tenant.current).try(:store_order_respose_log)

    file_name = "#{Time.current.strftime('%F')}_#{Apartment::Tenant.current}_se_import.json"
    file = GroovS3.get_file("#{Apartment::Tenant.current}/se_import_log/#{file_name}")
    if file.nil?
      file = GroovS3.create(Apartment::Tenant.current, "se_import_log/#{file_name}", 'text/json')
      begin
        File.open(file_name, 'w') { |f| f.write(data.to_yaml.force_encoding('utf-8')) }
      rescue StandardError
        File.open(file_name, 'w') { |f| f.write(data.as_json.to_yaml.force_encoding('utf-8')) }
      end
    else
      begin
        File.open(file_name, 'w') { |f| f.write(file.content.force_encoding('utf-8')) }
      rescue StandardError
        File.open(file_name, 'w') { |f| f.write(data.as_json.to_yaml.force_encoding('utf-8')) }
      end
      begin
        File.open(file_name, 'a') { |f| f.write(data.to_yaml.force_encoding('utf-8')) }
      rescue StandardError
        File.open(file_name, 'a') { |f| f.write(data.as_json.to_yaml.force_encoding('utf-8')) }
      end
    end
    file.acl = 'public-read'
    file.content = File.read(file_name)
    file.save
  rescue StandardError => e
    puts e
  end

  def retrieve_se_import_data
    return unless store_order_respose_log

    se_import_data = []
    GroovS3.bucket.objects(prefix: "#{name}/se_import_log").last(3).each do |obj|
      data = {
        date: Date.parse(obj.key.split('/se_import_log/').last),
        url: obj.url.gsub('http:', 'https:')
      }
      se_import_data << data
    end
    se_import_data
  end

  private

  def initialize_default_settings
    self.mark_discrepancies_scanned ||= true if mark_discrepancies_scanned.nil?
  end
end
