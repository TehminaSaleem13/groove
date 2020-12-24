class AddPerBoxLabelCreationToGeneralSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :general_settings, :per_box_shipping_label_creation, :string, default: 'per_box_shipping_label_creation_none'
  end
end
