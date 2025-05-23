# frozen_string_literal: true

class User < ApplicationRecord
  include InventoryWarehouseHelper
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  # Setup accessible (or protected) attributes for your model
  # attr_accessible :username, :password, :password_confirmation, :remember_me, :confirmation_code, :email
  validates :username, :confirmation_code, presence: true
  validates :username, uniqueness: { case_sensitive: false }
  validates :confirmation_code, uniqueness: true
  validates :confirmation_code, length: { maximum: 25 }

  # attr_accessible :title, :body
  belongs_to :inventory_warehouse, optional: true
  belongs_to :role, optional: true
  belongs_to :tote_set, optional: true
  has_many :user_inventory_permissions, dependent: :destroy
  has_many :order_activities , -> { order(activitytime: :desc) }
  has_many :product_activities, -> { order(activitytime: :desc) }
  has_many :doorkeeper_tokens, class_name: 'Doorkeeper::AccessToken', foreign_key: :resource_owner_id

  has_one :last_order_activity, -> { order('id DESC').limit(1) }, class_name: 'OrderActivity'
  has_one :last_product_activity, -> { order('id DESC').limit(1) }, class_name: 'ProductActivity'

  before_save :check_inventory_presence
  after_save :check_fix_permissions
  # before_create 'User.can_create_new?'
  before_validation :assign_confirmation_code
  before_save :update_total_login_time


  def self.current
    Thread.current[:user]
  end

  def self.current=(user)
    Thread.current[:user] = user
  end

  def email_required?
    false
  end

  def email_changed?
    false
  end

  def will_save_change_to_email?
    false
  end

  def active_for_authentication?
    super && active
  end

  def check_inventory_presence
    return unless inventory_warehouse_id.nil?
    return if InventoryWarehouse.where(is_default: true).first.nil?

    self.inventory_warehouse_id = InventoryWarehouse.where(is_default: true).first.id
  end

  def check_fix_permissions
    InventoryWarehouse.all.each do |inv_wh|
      fix_user_inventory_permissions(self, inv_wh)
    end
  end

  def can?(permission)
    return if role.nil?

    if role.make_super_admin
      # Super admin has all permissions
      true
    elsif %w[create_edit_notes change_order_status import_orders update_inventories].include?(permission)
      # A user with add_edit_order_items permission can do anything with an order
      role.add_edit_order_items || role[permission]
    else
      role[permission]
    end
  end

  def self.can_create_new?
    return if AccessRestriction.order('created_at').last.nil?

    where(active: true, is_deleted: false).count < AccessRestriction.last.num_users + 1
  end

  def assign_confirmation_code
    while true && confirmation_code.nil?
      random_code = rand(9999).to_s.center(4, rand(3).to_s).to_s
      if User.where(confirmation_code: random_code).empty?
        self.confirmation_code = random_code
        break
      end
    end
  end

  def last_activity
    order_change_time = last_order_activity.try(:updated_at)
    product_change_time = last_product_activity.try(:updated_at)
    scan_time = order_change_time.to_i > product_change_time.to_i ? order_change_time : product_change_time
    login_time = last_sign_in_at
    scan_time.to_i > login_time.to_i ? scan_time : login_time
  end

  def self.users_with_unique_filtered_order_count
   self.left_outer_joins(:order_activities)
    .where(is_deleted: false)
    .distinct
    .pluck(:username)
    .map do |username|
      {
        username: username,
        unique_order_count: Order.joins(:assigned_user)
                                 .where(users: { username: username })
                                 .count.to_s || "0"
      }
    end
  end
    
  def update_total_login_time
    # return if last_login_time.blank?
    end_time = last_logout_time 
    today = Time.current.beginning_of_day..Time.current.end_of_day
    if today.cover?(last_login_time) && today.cover?(end_time) 
      if last_login_time < end_time
        duration_in_seconds = end_time - last_login_time
        minutes_today = (duration_in_seconds / 60).to_i
    
        self.total_login_time ||= 0
        self.total_login_time += minutes_today
      end
    else
      # If the login time is not today, reset the total login time
      self.total_login_time = 0
    end
  end
end
