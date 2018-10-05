class AddColumnAddedThroughUiToAccessRestrictions < ActiveRecord::Migration
  def change
    add_column :access_restrictions, :added_through_ui, :integer , :default => 0
  end
end
