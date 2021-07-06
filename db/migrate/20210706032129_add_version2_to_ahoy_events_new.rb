class AddVersion2ToAhoyEventsNew < ActiveRecord::Migration[5.1]
  def change
    add_column :ahoy_events, :version_2, :boolean unless column_exists? :ahoy_events, :version_2
  end
end
