class AddAdminEmailToGeneralSettings < ActiveRecord::Migration
  def up
    add_column :general_settings, :admin_email, :string

    #move admin email from users to general_settings, if needed
    super_admin_role = Role.find_by_name('Super Admin')
    unless super_admin_role.nil?
      User.where(role_id: super_admin_role.id).each do |user|
        general_setting = GeneralSetting.first
        unless general_setting.nil?
          general_setting.admin_email = user.email
          general_setting.save
        end
      end
    end
  end

  def down
    remove_column :general_settings, :admin_email
  end
end
