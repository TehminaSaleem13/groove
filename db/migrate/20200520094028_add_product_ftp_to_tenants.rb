class AddProductFtpToTenants < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :product_ftp_import, :boolean, default: false
  end
end
