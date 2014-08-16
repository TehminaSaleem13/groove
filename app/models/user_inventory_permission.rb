class UserInventoryPermission < ActiveRecord::Base

  attr_accessible :see, :edit, :user_id, :inventory_warehouse_id

  belongs_to :inventory_warehouse
  belongs_to :user

  before_save :check_update_fields

  def check_update_fields
    unless self.see
      self.see = true if self.edit
    end
  end

end
