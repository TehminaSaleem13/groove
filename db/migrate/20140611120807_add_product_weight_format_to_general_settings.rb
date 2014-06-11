class AddProductWeightFormatToGeneralSettings < ActiveRecord::Migration
  def up
    add_column :general_settings, :product_weight_format, :string
  end
  def down
  	remove_column :general_settings, :product_weight_format
  end
end
