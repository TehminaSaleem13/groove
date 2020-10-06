class AddActivityTypeToOrderActivities < ActiveRecord::Migration[5.1]
  def change
    add_column :order_activities, :activity_type, :string
  end
end
