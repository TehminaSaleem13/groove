class AddOverridePassScanningToUsers < ActiveRecord::Migration[5.1]
  def up
    add_column :users, :override_pass_scanning, :boolean, default: false

    super_admin_role = Role.find_by_name('Super Admin')

    unless super_admin_role.nil?
      # Update users with the Super Admin role
      User.where(role_id: super_admin_role.id).update_all(override_pass_scanning: true)
    end
  end

  def down
    remove_column :users, :override_pass_scanning
  end
end
