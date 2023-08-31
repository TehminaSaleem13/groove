# frozen_string_literal: true

class ChangeStoreNameLimitOfOriginStore < ActiveRecord::Migration[5.1]
  def up
    change_column :origin_stores, :store_name, :string, limit: 25
  end

  def down
    change_column :origin_stores, :store_name, :string, limit: 20
  end
end
