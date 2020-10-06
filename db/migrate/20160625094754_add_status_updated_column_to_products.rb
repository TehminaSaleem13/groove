class AddStatusUpdatedColumnToProducts < ActiveRecord::Migration[5.1]
  def change
    add_column :products, :status_updated, :boolean, :default => false
  end
end
