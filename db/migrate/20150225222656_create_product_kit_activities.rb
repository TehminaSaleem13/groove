class CreateProductKitActivities < ActiveRecord::Migration
  def change
    create_table :product_kit_activities do |t|
      t.integer :product_id
      t.string :activity_message
      t.string :username
      t.string :activity_type

      t.timestamps
    end
  end
end
