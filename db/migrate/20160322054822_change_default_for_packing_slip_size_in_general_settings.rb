class ChangeDefaultForPackingSlipSizeInGeneralSettings < ActiveRecord::Migration[5.1]
  def up
    change_column :general_settings, :packing_slip_size, :string, :default=> '4 x 6'
  end

  def down
    change_column :general_settings, :packing_slip_size, :string, {:default=>nil}
  end
end
