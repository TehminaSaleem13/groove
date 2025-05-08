class RenameWeightToLengthInCartTotes < ActiveRecord::Migration[6.1]
  def change
    rename_column :cart_totes, :weight, :length
  end
end
