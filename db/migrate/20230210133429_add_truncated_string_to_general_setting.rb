class AddTruncatedStringToGeneralSetting < ActiveRecord::Migration[5.1]
  def change
    add_column :general_settings, :truncated_string, :string, default: "-"
  end
end
