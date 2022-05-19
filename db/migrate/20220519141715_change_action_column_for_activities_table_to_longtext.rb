class ChangeActionColumnForActivitiesTableToLongtext < ActiveRecord::Migration[5.1]
  def change
    change_column :order_activities, :action, :longtext
    change_column :product_activities, :action, :longtext
  end
end
