class AddPlatformToOrderActivity < ActiveRecord::Migration[5.1]
  def change
    add_column :order_activities, :platform, :string
  end
end
