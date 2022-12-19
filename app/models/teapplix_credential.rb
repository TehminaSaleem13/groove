# frozen_string_literal: true

class TeapplixCredential < ActiveRecord::Base
  # attr_accessible :account_name, :password, :store_id, :username, :import_shipped, :import_open_orders, :last_imported_at
  before_save :check_if_null_or_undefined
  belongs_to :store

  private

  def check_if_null_or_undefined
    arr = %w[null undefined]
    self.username = nil if arr.include?(username)
    self.password = nil if arr.include?(password)
  end
end
