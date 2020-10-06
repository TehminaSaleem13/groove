class AddUsernameToOrderActivities < ActiveRecord::Migration[5.1]
  def change
    add_column :order_activities, :username , :string
  end
end
