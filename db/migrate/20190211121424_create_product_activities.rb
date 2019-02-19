class CreateProductActivities < ActiveRecord::Migration
  def change
    create_table :product_activities do |t|
      t.datetime :activitytime
      t.references :product
      t.references :user
      t.string :action
      t.string :username
      t.string :activity_type
      t.boolean  :acknowledged, :default =>false
      
      t.timestamps
    end
    add_index :product_activities, :product_id
    add_index :product_activities, :user_id
  end
end
