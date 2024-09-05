# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: { writing: :write_database, reading: :read_database }
end
