class AddActivityTypeToOrderActivities < ActiveRecord::Migration
  def change
    add_column :order_activities, :activity_type, :string
  end
end
