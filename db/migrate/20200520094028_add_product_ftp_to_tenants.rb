class AddProductFtpToTenants < ActiveRecord::Migration
  def change
    add_column :tenants, :product_ftp_import, :boolean, default: false
  end
end
