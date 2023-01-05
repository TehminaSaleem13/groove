class AddPackingSlipColumnToUser < ActiveRecord::Migration[5.1]
  def change
    general_setting = GeneralSetting.last
    default_value = general_setting&.packing_slip_size || '4 x 6'
    add_column :users, :packing_slip_size, :string, default: default_value
  end
end
