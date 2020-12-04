class AddDirectPrintOptionsToTenants < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :direct_printing_options, :boolean, default: false
  end
end
