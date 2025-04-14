class AddVoicePackingToTenants < ActiveRecord::Migration[6.1]
  def change
    add_column :tenants, :voice_packing, :boolean, default: false
  end
end