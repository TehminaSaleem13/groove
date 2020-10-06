class AddCustomFieldToUser < ActiveRecord::Migration[5.1]  
  def change
    add_column :users, :custom_field_one, :string
    add_column :users, :custom_field_two, :string
  end
end
