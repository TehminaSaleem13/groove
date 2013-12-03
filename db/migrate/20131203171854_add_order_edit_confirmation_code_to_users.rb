class AddOrderEditConfirmationCodeToUsers < ActiveRecord::Migration
  def change
    add_column :users, :order_edit_confirmation_code, :string, :default=>""
  end
end
