class AddNewColumnToVeeqoCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :veeqo_credentials, :import_tracking_info, :boolean, default: true
    add_column :veeqo_credentials, :remove_cancelled_orders, :boolean, default: true
    add_column :veeqo_credentials, :import_upc, :boolean, default: true
    add_column :veeqo_credentials, :set_coupons_to_intangible, :boolean, default: true
  end
end
