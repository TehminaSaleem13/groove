class ChangeNotesTypeInOrders < ActiveRecord::Migration
  def up
    change_column :orders, :notes_internal, :text
    change_column :orders, :notes_toPacker, :text
    change_column :orders, :notes_fromPacker, :text
    change_column :orders, :customer_comments, :text
  end

  def down
    change_column :orders, :notes_internal, :string
    change_column :orders, :notes_toPacker, :string
    change_column :orders, :notes_fromPacker, :string
    change_column :orders, :customer_comments, :string
  end
end
