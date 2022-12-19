# frozen_string_literal: true

require 'ahoy'

class Ahoy::Store < Ahoy::DatabaseStore
  def visit_model
    Visit
  end
end
Ahoy.geocode = false
Ahoy.server_side_visits = :when_needed
