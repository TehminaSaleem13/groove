class AddOrderEditConfirmationCodeToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :order_edit_confirmation_code, :string, :default=>""
  end
end
