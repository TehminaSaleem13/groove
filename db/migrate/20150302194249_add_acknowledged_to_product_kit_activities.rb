class AddAcknowledgedToProductKitActivities < ActiveRecord::Migration
  def change
    add_column :product_kit_activities, :acknowledged, :boolean, default: false
  end
end
