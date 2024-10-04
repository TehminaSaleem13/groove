# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StopAllImportsJob, type: :job do
  let(:tenant) { create(:tenant, name: Apartment::Tenant.current) }

  before do
    allow(Tenant).to receive(:find_each).and_yield(tenant)
    allow(Apartment::Tenant).to receive(:switch!)

    create(:import_item, status: 'in_progress')
    create(:import_item, status: 'not_started')
    create(:import_item, status: 'failed')
    create(:import_item, status: 'completed')

    create(:order_import_summary, status: 'pending')
    create(:order_import_summary, status: 'completed')
  end

  it 'cancels import items and completes order import summaries for the tenant' do
    expect(ImportItem).to receive_message_chain(:where, :update_all)

    perform_enqueued_jobs { described_class.perform_later }
  end

  it 'does not update completed order import summaries' do
    expect_any_instance_of(OrderImportSummary).to receive(:update)

    perform_enqueued_jobs { described_class.perform_later }
  end

  it 'switches to the tenant' do
    perform_enqueued_jobs { described_class.perform_later }

    expect(Apartment::Tenant).to have_received(:switch!).with(tenant.name).once
  end
end
