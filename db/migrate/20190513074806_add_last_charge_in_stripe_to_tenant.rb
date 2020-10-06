class AddLastChargeInStripeToTenant < ActiveRecord::Migration[5.1]
  def change
     add_column :tenants, :last_charge_in_stripe, :datetime
  end
end
