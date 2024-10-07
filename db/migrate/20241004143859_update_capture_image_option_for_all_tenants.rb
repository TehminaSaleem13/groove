class UpdateCaptureImageOptionForAllTenants < ActiveRecord::Migration[6.1]
  def up
    change_column :scan_pack_settings, :capture_image_option, :string, default: "default"

    Tenant.all.each do |tenant|
      Apartment::Tenant.switch(tenant.name) do
        ScanPackSetting.where(capture_image_option: "0").update_all(capture_image_option: 'do_not_take_image')
        ScanPackSetting.where(capture_image_option: "1").update_all(capture_image_option: 'default')
      end
    end
  end

  def down
    change_column :scan_pack_settings, :capture_image_option, :string, default: 'do_not_take_image'
  end
end
