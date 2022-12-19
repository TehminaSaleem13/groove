# frozen_string_literal: true

require 'active_record'

namespace :update_split_order_for_shipping_easy do
  task update_split_order: :environment do
    Tenant.all.each do |tenant|
      Apartment::Tenant.switch!(tenant.name)
      store = Store.where(store_type: 'ShippingEasy', split_order: %w[0 1])
      store.update_all(split_order: 'disabled')
    end
  end
end
