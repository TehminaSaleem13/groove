class AddConfirmationToOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :note_confirmation, :boolean, :default => false
  end
end
