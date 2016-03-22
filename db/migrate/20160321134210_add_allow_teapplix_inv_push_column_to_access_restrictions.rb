class AddAllowTeapplixInvPushColumnToAccessRestrictions < ActiveRecord::Migration
  def change
    add_column :access_restrictions, :allow_teapplix_inv_push, :boolean, default: false
  end
end
