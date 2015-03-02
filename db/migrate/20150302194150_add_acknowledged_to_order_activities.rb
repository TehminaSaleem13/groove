class AddAcknowledgedToOrderActivities < ActiveRecord::Migration
  def change
    add_column :order_activities, :acknowledged, :boolean, default: false
  end
end
