class AddVersion2ToAhoyEvents < ActiveRecord::Migration[5.1]
  def change
    add_column :ahoy_events, :version_2, :boolean, default: false
  end
end
