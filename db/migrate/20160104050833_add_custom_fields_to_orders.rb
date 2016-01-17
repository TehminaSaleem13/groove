class AddCustomFieldsToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :custom_field_one, :string
    add_column :orders, :custom_field_two, :string
  end
end
