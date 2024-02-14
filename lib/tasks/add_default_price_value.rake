# frozen_string_literal: true

namespace :doo do
  desc 'Add default pice vale to each tenant'
  task add_default_price_value_to_tenant: :environment do
    tenants = begin
                Tenant.order(:name)
              rescue StandardError
                Tenant.all
              end
    tenants.each do |tenant|
      tenant.price = { 'bigCommerce_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'shopify_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'magento2_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'teapplix_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'product_activity_log_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'magento_soap_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'multi_box_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'amazon_fba_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'post_scanning_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'allow_Real_time_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'import_option_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'inventory_report_option_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'custom_product_fields_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'enable_developer_tools_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' } }
      tenant.save
    rescue StandardError
    end
  end

  task update_price_value_to_tenant: :environment do
    tenants = begin
                Tenant.order(:name)
              rescue StandardError
                Tenant.all
              end
    tenants.each do |tenant|
      new_price = tenant.price.merge('high_sku_feature' => { 'toggle' => false, 'amount' => 50, 'stripe_id' => '' }, 'double_high_sku' => { 'toggle' => false, 'amount' => 100, 'stripe_id' => '' }, 'cust_maintenance_1' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' }, 'cust_maintenance_2' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' })
      tenant.price = new_price
      tenant.save
    rescue StandardError
    end
  end

  task update_price_value: :environment do
    tenants = begin
                Tenant.order(:name)
              rescue StandardError
                Tenant.all
              end
    tenants.each do |tenant|
      new_price = tenant.price.merge('groovelytic_stat_feature' => { 'toggle' => false, 'amount' => 30, 'stripe_id' => '' })
      tenant.price = new_price
      tenant.save
    rescue StandardError
    end
  end
end
