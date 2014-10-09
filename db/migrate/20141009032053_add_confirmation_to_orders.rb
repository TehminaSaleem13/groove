class AddConfirmationToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :note_confirmation, :boolean, :default => false
  end
end
