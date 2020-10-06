class AddAllowDuplicateToStore < ActiveRecord::Migration[5.1]
  def change
  	add_column :shipping_easy_credentials, :allow_duplicate_id, :boolean, :default => false
  end
end
