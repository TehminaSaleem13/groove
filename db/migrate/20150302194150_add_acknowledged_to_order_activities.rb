class AddAcknowledgedToOrderActivities < ActiveRecord::Migration[5.1]
  def change
    add_column :order_activities, :acknowledged, :boolean, default: false
  end
end
