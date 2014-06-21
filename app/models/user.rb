class User < ActiveRecord::Base

  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :username, :password, :password_confirmation, :remember_me, :confirmation_code
  validates_presence_of  :username, :confirmation_code
  validates_uniqueness_of :username, :case_sensitive => false
  # attr_accessible :title, :body
  belongs_to :inventory_warehouse
  belongs_to :role

  def email_required?
    false
  end

  def can? permission
    if self.role.make_super_admin
      #Super admin has all permissions
      return true
    elsif ['create_edit_notes','change_order_status','import_orders'].include?(permission)
      #A user with add_edit_order_items permission can do anything with an order
      return (self.role.add_edit_order_items || self.role[permission])
    else
      return self.role[permission]
    end
  end
end
