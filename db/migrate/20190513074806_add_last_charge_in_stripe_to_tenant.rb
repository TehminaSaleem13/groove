class AddLastChargeInStripeToTenant < ActiveRecord::Migration
  def change
     add_column :tenants, :last_charge_in_stripe, :datetime
  end
end
