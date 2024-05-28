class RemoveSsLabelDataFromOrders < ActiveRecord::Migration[5.1]
  def change
    remove_column :orders, :ss_label_data, :largetext
  end
end
