class AddAllowMgRestInvPushColumnToAccessRestriction < ActiveRecord::Migration
  def change
    add_column :access_restrictions, :allow_mg_rest_inv_push, :boolean, :default => false
  end
end
