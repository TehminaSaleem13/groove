class AddProductEditConfirmationCodeToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :product_edit_confirmation_code, :string, :default=>""
  end
end
