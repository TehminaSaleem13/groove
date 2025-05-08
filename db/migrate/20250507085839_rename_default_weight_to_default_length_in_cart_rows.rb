class RenameDefaultWeightToDefaultLengthInCartRows < ActiveRecord::Migration[6.1]
  def change
    rename_column :cart_rows, :default_weight, :default_length
  end
end



