class AddAllowMgRestInvPushColumnToAccessRestriction < ActiveRecord::Migration[5.1]
  def change
    add_column :access_restrictions, :allow_mg_rest_inv_push, :boolean, :default => false
  end
end
