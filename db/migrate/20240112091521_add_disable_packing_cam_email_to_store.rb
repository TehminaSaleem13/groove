class AddDisablePackingCamEmailToStore < ActiveRecord::Migration[5.1]
  def change
    add_column :stores, :disable_packing_cam_email, :boolean, default: false
  end
end
