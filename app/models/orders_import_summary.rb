# frozen_string_literal: true

class OrdersImportSummary < ApplicationRecord
  belongs_to :store
  # attr_accessible :error_message, :previous_imported, :status, :success_imported, :total_retrieved
end
