class UpdateCaptureImageDefaultOptionForAllTenants < ActiveRecord::Migration[6.1]
  def up
    change_column :scan_pack_settings, :capture_image_option, :string, default: 'automatic'

    Tenant.all.each do |tenant|
      Apartment::Tenant.switch(tenant.name) do
        ScanPackSetting.where(capture_image_option: 'default').update_all(capture_image_option: 'automatic')
      end
    end
  end

  def down
    change_column :scan_pack_settings, :capture_image_option, :string, default: 'default'

    Tenant.all.each do |tenant|
      Apartment::Tenant.switch(tenant.name) do
        ScanPackSetting.where(capture_image_option: 'automatic').update_all(capture_image_option: 'default')
      end
    end
  end
end
