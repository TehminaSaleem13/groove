class AddColumnsToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :notes_internal, :string
    add_column :orders, :notes_toPacker, :string
    add_column :orders, :notes_fromPacker, :string
    add_column :orders, :tracking_processed, :boolean
  end
end
