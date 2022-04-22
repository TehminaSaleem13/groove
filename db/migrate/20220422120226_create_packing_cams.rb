class CreatePackingCams < ActiveRecord::Migration[5.1]
  def change
    create_table :packing_cams do |t|
      t.references :order, index: true, null: false
      t.references :order_item, index: true
      t.references :user, index: true, null: false
      t.string :url
      t.string :username

      t.timestamps
    end
  end
end
