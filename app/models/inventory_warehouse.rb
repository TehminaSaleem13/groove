class InventoryWarehouse < ActiveRecord::Base
  attr_accessible :location, :name, :status, :is_default

  has_many :users, :dependent => :nullify
  has_many :user_inventory_permissions, :dependent => :destroy
  has_many :product_inventory_warehousess
  has_many :stores

  validates_presence_of :name
  validates_uniqueness_of :name

  after_save :check_fix_permissions

  def check_fix_permissions
    User.all.each do |user|
      if UserInventoryPermission.where(:user_id => user.id,:inventory_warehouse_id => self.id).length == 0
        UserInventoryPermission.create(
            :user_id => user.id,
            :inventory_warehouse_id => self.id,
            :see => !(user.can?('make_super_admin') || (user.inventory_warehouse_id == self.id)).blank?,
            :edit => !(user.can?('make_super_admin') || ((user.inventory_warehouse_id == self.id) && user.can?('add_edit_product'))).blank?
        )
      end
    end
  end
end
