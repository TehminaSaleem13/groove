class AddCustomFieldsToOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :custom_field_one, :string
    add_column :orders, :custom_field_two, :string
  end
end
