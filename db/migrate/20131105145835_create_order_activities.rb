class CreateOrderActivities < ActiveRecord::Migration
  def change
    create_table :order_activities do |t|
      t.datetime :activitytime
      t.references :order
      t.references :user
      t.string :action

      t.timestamps
    end
    add_index :order_activities, :order_id
    add_index :order_activities, :user_id
  end
end
