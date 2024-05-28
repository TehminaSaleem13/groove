class CreateShipstationLabelData < ActiveRecord::Migration[5.1]
  def change
    create_table :shipstation_label_data do |t|
      t.longtext :content
      t.bigint :order_id, null: false

      t.timestamps
    end unless table_exists?(:shipstation_label_data)

    add_index :shipstation_label_data, :order_id unless index_exists?(:shipstation_label_data, :order_id)

    execute "ALTER TABLE shipstation_label_data MODIFY content LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

    Order.reset_column_information

    orders_with_ss_label_data = Order.where.not(ss_label_data: nil).pluck(:id, :ss_label_data).to_h
    bulk_data = orders_with_ss_label_data.collect do |k,v|
      { order_id: k, content: v.as_json }
    end
    ShipstationLabelData.import bulk_data, batch_size: 50 if bulk_data.any?
  end
end
