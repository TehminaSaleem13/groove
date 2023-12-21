class AddDisablePackingCamToStore < ActiveRecord::Migration[5.1]
  def change
    add_column :stores, :disable_packing_cam, :boolean, default: false
  end
end
