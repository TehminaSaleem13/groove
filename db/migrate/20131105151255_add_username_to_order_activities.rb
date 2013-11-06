class AddUsernameToOrderActivities < ActiveRecord::Migration
  def change
    add_column :order_activities, :username
  end
end
