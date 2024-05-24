class RenameAndChangeUseOriginalOrderNumberInVeeqoCredentia < ActiveRecord::Migration[5.1]
  def up
    rename_column :veeqo_credentials, :use_original_order_number, :use_veeqo_order_id
    change_column :veeqo_credentials, :use_veeqo_order_id, :boolean, default: false
  end

  def down
    rename_column :veeqo_credentials, :use_veeqo_order_id, :use_original_order_number
    change_column :veeqo_credentials, :use_original_order_number, :boolean, default: true
  end
end
