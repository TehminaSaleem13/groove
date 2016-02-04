class RenameColumnAllowInvPushToallowBcInvPush < ActiveRecord::Migration
  def up
  	rename_column :access_restrictions, :allow_inv_push, :allow_bc_inv_push
  end

  def down
  	rename_column :access_restrictions, :allow_bc_inv_push, :allow_inv_push
  end
end
