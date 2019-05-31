class AddAllowDuplicateOrderToShipstation < ActiveRecord::Migration
  def change
    add_column :shipstation_rest_credentials, :allow_duplicate_order, :boolean, :default => false
  end
end
