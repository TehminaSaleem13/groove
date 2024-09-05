# frozen_string_literal: true

module Ahoy
  class Event < ApplicationRecord
    include Ahoy::Properties

    default_scope { where(version_2: false) }
    scope :version_2, -> { unscoped.where(version_2: true) }

    self.table_name = 'ahoy_events'

    belongs_to :visit, optional: true
    belongs_to :user, optional: true

    serialize :properties, JSON
  end
end
