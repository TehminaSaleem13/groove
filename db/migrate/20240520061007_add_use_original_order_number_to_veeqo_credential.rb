class AddUseOriginalOrderNumberToVeeqoCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :veeqo_credentials, :use_original_order_number, :boolean, default: true
  end
end
