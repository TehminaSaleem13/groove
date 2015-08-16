class InventoryWarehouse < ActiveRecord::Base
  include InventoryWarehouseHelper
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
      fix_user_inventory_permissions(user, self)
    end
  end
end
