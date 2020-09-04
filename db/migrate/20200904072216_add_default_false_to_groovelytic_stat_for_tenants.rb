class AddDefaultFalseToGroovelyticStatForTenants < ActiveRecord::Migration
  def change
    change_column_default :tenants, :groovelytic_stat, false
  end
end
