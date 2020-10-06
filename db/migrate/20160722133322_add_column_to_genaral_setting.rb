class AddColumnToGenaralSetting < ActiveRecord::Migration[5.1]
  def change
  	add_column :general_settings, :search_by_product, :boolean, :default => false
  end
end
