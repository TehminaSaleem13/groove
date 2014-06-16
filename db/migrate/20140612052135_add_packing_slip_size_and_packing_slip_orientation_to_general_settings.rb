class AddPackingSlipSizeAndPackingSlipOrientationToGeneralSettings < ActiveRecord::Migration
  def up
    add_column :general_settings, :packing_slip_size, :string
    add_column :general_settings, :packing_slip_orientation, :string
  end
  def down
  	remove_column :general_settings, :packing_slip_size
  	remove_column :general_settings, :packing_slip_orientation  	
  end
end
