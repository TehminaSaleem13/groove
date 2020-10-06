class AddAcknowledgedToProductKitActivities < ActiveRecord::Migration[5.1]
  def change
    add_column :product_kit_activities, :acknowledged, :boolean, default: false
  end
end
