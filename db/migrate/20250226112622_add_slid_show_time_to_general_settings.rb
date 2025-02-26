class AddSlidShowTimeToGeneralSettings < ActiveRecord::Migration[6.1]
  def change
    add_column :general_settings, :slidShowTime, :integer , default: 15
  end
end
