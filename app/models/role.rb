class Role < ActiveRecord::Base
  attr_accessible :name, :display
  validates_presence_of  :name
  validates_uniqueness_of :name, :case_sensitive => false

  has_many :users
end
