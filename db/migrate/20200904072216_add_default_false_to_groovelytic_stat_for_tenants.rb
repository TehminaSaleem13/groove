class AddDefaultFalseToGroovelyticStatForTenants < ActiveRecord::Migration[5.1]
  def change
    change_column_default :tenants, :groovelytic_stat, false
  end
end
