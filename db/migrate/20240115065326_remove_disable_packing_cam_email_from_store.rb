class RemoveDisablePackingCamEmailFromStore < ActiveRecord::Migration[5.1]
  def change
    remove_column :stores, :disable_packing_cam_email
  end
end
