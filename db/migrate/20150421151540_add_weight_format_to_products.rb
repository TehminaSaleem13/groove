class AddWeightFormatToProducts < ActiveRecord::Migration
  def change
    add_column :products, :weight_format, :string
  end
end
