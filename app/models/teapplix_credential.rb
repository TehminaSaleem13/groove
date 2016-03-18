class TeapplixCredential < ActiveRecord::Base
  attr_accessible :account_name, :password, :store_id, :username, :import_shipped, :import_open_orders, :last_imported_at
  before_save :check_if_null_or_undefined
  belongs_to :store

  private
    def check_if_null_or_undefined
      self.username = nil if self.username=="null" or self.username=="undefined"
      self.password = nil if self.password=="null" or self.password=="undefined"
    end
end
