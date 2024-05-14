class RenameGroovepackerIdColumnToGroovepackerTagOrigin < ActiveRecord::Migration[5.1]
  def change
    rename_column :order_tags, :groovepacker_id, :groovepacker_tag_origin
  end
end
