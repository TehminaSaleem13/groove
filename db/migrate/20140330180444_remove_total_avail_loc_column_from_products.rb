class RemoveTotalAvailLocColumnFromProducts < ActiveRecord::Migration[5.1]
  def up
  	remove_column :products, :total_avail_loc
  end

  def down
    add_column :products, :total_avail_loc, :integer, :default =>0, :null=> false
  end
end
