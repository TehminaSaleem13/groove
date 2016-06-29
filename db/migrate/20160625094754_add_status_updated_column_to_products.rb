class AddStatusUpdatedColumnToProducts < ActiveRecord::Migration
  def change
    add_column :products, :status_updated, :boolean, :default => false
  end
end
