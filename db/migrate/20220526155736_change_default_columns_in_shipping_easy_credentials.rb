class ChangeDefaultColumnsInShippingEasyCredentials < ActiveRecord::Migration[5.1]
  def up
    change_column :shipping_easy_credentials, :allow_duplicate_id, :boolean, default: true
  end

  def down
    change_column :shipping_easy_credentials, :allow_duplicate_id, :boolean, default: false
  end
end
