class AddCustomFieldToUser < ActiveRecord::Migration  
  def change
    add_column :users, :custom_field_one, :string
    add_column :users, :custom_field_two, :string
  end
end
