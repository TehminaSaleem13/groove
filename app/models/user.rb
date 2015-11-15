class User < ActiveRecord::Base
  include InventoryWarehouseHelper
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :username, :password, :password_confirmation, :remember_me, :confirmation_code
  validates_presence_of :username, :confirmation_code
  validates_uniqueness_of :username, :case_sensitive => false
  validates_uniqueness_of :confirmation_code
  validates :confirmation_code, length: {maximum: 25}

  # attr_accessible :title, :body
  belongs_to :inventory_warehouse
  belongs_to :role
  has_many :user_inventory_permissions, :dependent => :destroy

  before_save :check_inventory_presence
  after_save :check_fix_permissions
  before_create 'User.can_create_new?'
  before_validation :assign_confirmation_code

  def email_required?
    false
  end

  def email_changed?
    false
  end

  def active_for_authentication?
    super && self.active
  end

  def check_inventory_presence
    if self.inventory_warehouse_id.nil?
      unless InventoryWarehouse.where(:is_default => true).first.nil?
        self.inventory_warehouse_id = InventoryWarehouse.where(:is_default => true).first.id
      end
    end
  end

  def check_fix_permissions
    InventoryWarehouse.all.each do |inv_wh|
      fix_user_inventory_permissions(self, inv_wh)
    end
  end

  def can? permission
    unless self.role.nil?
      if self.role.make_super_admin
        #Super admin has all permissions
        return true
      elsif ['create_edit_notes', 'change_order_status', 'import_orders', 'update_inventories'].include?(permission)
        #A user with add_edit_order_items permission can do anything with an order
        return (self.role.add_edit_order_items || self.role[permission])
      else
        return self.role[permission]
      end
    end
  end

  def self.can_create_new?
    unless AccessRestriction.order("created_at").last.nil?
      self.all.count < AccessRestriction.order("created_at").last.num_users + 1
    end
  end

  def assign_confirmation_code
    while true && self.confirmation_code.nil?
      random_code = rand(9999).to_s.center(4, rand(3).to_s).to_s
      if User.where(confirmation_code: random_code).length == 0
        self.confirmation_code = random_code
        break
      end
    end
  end
end
