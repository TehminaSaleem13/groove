class CreateShippingLabels < ActiveRecord::Migration[5.1]
  def change
    create_table :shipping_labels do |t|
      t.bigint :order_id
      t.bigint :shipment_id
      t.text :url

      t.timestamps
    end
  end
end
