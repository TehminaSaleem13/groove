class AddConfirmationCodeToUsers < ActiveRecord::Migration
  def change
    add_column :users, :confirmation_code, :string, :default=>""
    remove_column :users, :order_edit_confirmation_code
	remove_column :users, :product_edit_confirmation_code
  end
end
