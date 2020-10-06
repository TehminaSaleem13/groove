class AddWeightFormatToProducts < ActiveRecord::Migration[5.1]
  def change
    add_column :products, :weight_format, :string
  end
end
