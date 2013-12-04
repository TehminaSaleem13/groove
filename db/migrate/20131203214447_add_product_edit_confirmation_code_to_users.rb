class AddProductEditConfirmationCodeToUsers < ActiveRecord::Migration
  def change
    add_column :users, :product_edit_confirmation_code, :string, :default=>""
  end
end
