# frozen_string_literal: true

class StopAllImportsJob < ApplicationJob
  queue_as :default

  def perform(*_args)
    Tenant.find_each do |tenant|
      Apartment::Tenant.switch!(tenant.name)

      cancel_import_items
      complete_order_import_summaries
    end
  end

  private

  def cancel_import_items
    ImportItem.where(status: %w[in_progress not_started failed]).update_all(status: 'cancelled')
  end

  def complete_order_import_summaries
    OrderImportSummary.where.not(status: 'completed').find_each do |import_summary|
      import_summary.update(status: 'completed')
    end
  end
end
