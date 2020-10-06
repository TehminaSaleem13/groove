class AddSrtictCcToGeneralSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :general_settings, :strict_cc, :boolean, :default => false
    add_column :general_settings, :conf_code_product_instruction, :string, :default => 'optional'
  end
end
