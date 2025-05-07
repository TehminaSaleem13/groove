class AddGetProductDimensionFormatToGeneralSettings < ActiveRecord::Migration[6.1]
  def change
    add_column :general_settings, :product_dimension_unit, :string, default: 'inches'
  end
end
