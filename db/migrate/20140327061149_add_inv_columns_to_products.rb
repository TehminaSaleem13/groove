class AddInvColumnsToProducts < ActiveRecord::Migration[5.1]
  def change
    add_column :products, :total_avail_loc, :integer, :default =>0, :null=> false
    add_column :products, :total_avail_ext, :integer, :default =>0, :null=> false
  end
end
