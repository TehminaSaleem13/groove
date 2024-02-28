class ShoplinePriceDefaultSettingsForTenants < ActiveRecord::Migration[5.1]
  def up
    Tenant.all.each do |tenant|
      if tenant.price && !(tenant.price.has_key?('shopline_feature') || tenant.price.has_key?(:shopline_feature))
        tenant.price[:shopline_feature] = { toggle: false, amount: 30, stripe_id: '' }
        tenant.save!
      end
    end
  end

  def down
  end
end
