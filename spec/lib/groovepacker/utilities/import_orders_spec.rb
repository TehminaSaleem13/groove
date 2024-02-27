# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImportOrders do
  subject(:import_orders) { described_class.new }

  before do
    Groovepacker::SeedTenant.new.seed
  end

  describe '#schedule_inventory_report' do
    let(:general_settings) { GeneralSetting.all.first }
    let(:date) { Date.new(2023, 1, 1) }
    let(:should_schedule_job) { false }
    let(:time) { '9:00 AM' }
    let(:scheduled_reports) { double }
    let(:inventory_report_settings) { InventoryReportsSetting.first_or_create(report_email: 'example@example.com') }
    let(:result) { import_orders.schedule_inventory_report(general_settings, date, should_schedule_job, time) }

    before do
      allow(ProductInventoryReport).to receive(:where).with(scheduled: true).and_return(scheduled_reports)
      allow(InventoryReportsSetting).to receive(:last).and_return(inventory_report_settings)
    end

    context 'when scheduled_reports is blank or inventory_report_settings.report_email is blank' do
      let(:scheduled_reports) { [] }
      let(:inventory_report_settings) { InventoryReportsSetting.first_or_create(report_email: '') }

      it 'returns the original should_schedule_job and time' do
        expect(result).to eq([should_schedule_job, time])
      end
    end

    context 'when scheduled_reports is not blank and inventory_report_settings.report_email is present' do
      before do
        allow(inventory_report_settings).to receive(:should_send_email).with(date).and_return(true)
        allow(inventory_report_settings).to receive(:time_to_send_report_email).and_return('10:00 AM')
        result # Run the service and get the result
      end

      it 'calls should_send_email on inventory_report_settings with the given date' do
        expect(inventory_report_settings).to have_received(:should_send_email).with(date)
      end

      it 'calls time_to_send_report_email on inventory_report_settings' do
        expect(inventory_report_settings).to have_received(:time_to_send_report_email)
      end

      it 'returns the updated should_schedule_job and time' do
        allow(inventory_report_settings).to receive(:should_send_email).and_return(true)
        allow(inventory_report_settings).to receive(:time_to_send_report_email).and_return('10:00 AM')

        expect(result).to eq([true, '10:00 AM'])
      end
    end
  end

  describe '#import_shopify_orders_every_ten_mins' do

    before do
      inv_wh = create(:inventory_warehouse, name: 'csv_inventory_warehouse')
      tenant = Apartment::Tenant.current
      Apartment::Tenant.switch!(tenant.to_s)
      tenant = create(:tenant, name: tenant.to_s)
      create(:store, :shopify, status: true, inventory_warehouse: inv_wh) do |store|
        store.shopify_credential.update(webhook_order_import: true)
      end      
    end

    it 'imports Shopify orders for each tenant' do
      expect_any_instance_of(Groovepacker::ShopifyRuby::Client).to receive(:orders).and_return(YAML.safe_load(IO.read(Rails.root.join('spec/fixtures/files/shopify_test_order.yaml'))))

      expect do
        ImportOrders.new.import_shopify_orders_every_ten_mins
      end.to change(Order, :count).by(1)
    end
  end
end
