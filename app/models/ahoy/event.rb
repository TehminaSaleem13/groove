module Ahoy
  class Event < ActiveRecord::Base
    include Ahoy::Properties

    default_scope { where(version_2: false) }
    scope :version_2, -> { unscoped.where(version_2: true) }

    self.table_name = "ahoy_events"

    belongs_to :visit
    belongs_to :user

    serialize :properties, JSON
  end
end
