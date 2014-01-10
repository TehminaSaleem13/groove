class User < ActiveRecord::Base
  rolify
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :username, :password, :password_confirmation, :remember_me
  validates_presence_of  :username, :confirmation_code
  validates_uniqueness_of :username, :case_sensitive => false
  # attr_accessible :title, :body

  def email_required?
    false
  end
end
