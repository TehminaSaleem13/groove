class AddSoundSelectTypesToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :sound_selected_types, :json
  end
end
