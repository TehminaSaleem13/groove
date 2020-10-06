class MoveCsvMapToNewTable < ActiveRecord::Migration[5.1]
  def up
    CsvMapping.find_each do |mapping|
      unless mapping.product_map.blank? || mapping.store.nil?
        product_csv_map = CsvMap.create(
                  :custom => true,
                  :name => mapping.store.name.to_s+' - Default Product Mapping',
                  :kind => 'product',
                  :map => mapping.product_map
        )
        mapping.product_csv_map = product_csv_map
      end

      unless mapping.order_map.blank? || mapping.store.nil?
        order_csv_map = CsvMap.create(
            :custom => true,
            :name => mapping.store.name.to_s+' - Default Order Mapping',
            :kind => 'order',
            :map => mapping.order_map
        )
        mapping.order_csv_map = order_csv_map
      end

      mapping.save
    end

  end

  def down
  end
end
