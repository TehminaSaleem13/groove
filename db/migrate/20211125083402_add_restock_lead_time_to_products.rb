class AddRestockLeadTimeToProducts < ActiveRecord::Migration[5.1]
  def change
  	add_column :products, :restock_lead_time, :integer, default: 0
  end
end
