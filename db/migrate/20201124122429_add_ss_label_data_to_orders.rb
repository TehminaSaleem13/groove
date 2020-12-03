class AddSsLabelDataToOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :ss_label_data, :text
  end
end
