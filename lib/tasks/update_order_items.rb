# frozen_string_literal: true

namespace :system do
  desc 'Update Order Items'
  task update_order_items: :environment do
    tenants = Tenant.pluck(:name)
    unless tenants.empty?
      logger = Logger.new("#{Rails.root}/log/order_item_update_#{Apartment::Tenant.current}.log")
      logger.info("\n==Update STARTED==\n")

      tenants.each do |tenant|
        Apartment::Tenant.switch! tenant
        logger.info("\n==Tenant: #{tenant}==\n")
        OrderItem.all.each do |i|
          i.save
        rescue StandardError => e
          logger.info("\n==ERROR==\n")
          logger.info(Apartment::Tenant.current)
          logger.info("Item: #{i.as_json}")
          logger.info("Product: #{i.product&.as_json}")
        end
      end
      logger.info("\n==Update COMPLETED==\n")
    end
  end
end
