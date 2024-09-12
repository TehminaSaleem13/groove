# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InventoryReportMailer, type: :mailer do
  let(:tenant) { Apartment::Tenant.current }
  let(:inventory_report_mailer) { described_class.new }
  let(:product_inv_setting) { InventoryReportsSetting.first_or_create(report_email: 'test@example.com') }
  let(:product) { create(:product) }
  let(:report) { ProductInventoryReport.first_or_create(name: 'Active_Products_Report', is_locked: true, type: nil) }
  let(:sku_report) { ProductInventoryReport.first_or_create(name: 'Sku_Report', is_locked: true, type: 'sku_type') }
  let(:csv_data) { 'some,csv,data' }

  before do
    allow(Apartment::Tenant).to receive(:switch!).with(tenant)
    allow(InventoryReportsSetting).to receive(:last).and_return(product_inv_setting)
    allow_any_instance_of(InventoryReport::SkuPerDay).to receive(:get_data).and_return(csv_data)
    allow_any_instance_of(InventoryReport::InvProjection).to receive(:get_data).and_return(csv_data)
  end

  describe '#manual_inventory_report' do
    let(:mail) { described_class.manual_inventory_report(report.id, tenant) }

    context 'when reports are present' do
      it 'generates an email with the correct subject' do
        mail.deliver_now
        expect(mail.subject).to eq("Inventory Projection Report [#{tenant}]")
      end

      it 'attaches the correct file' do
        mail.deliver_now
        expect(mail.attachments.length).to eq(1)
        expect(mail.attachments.first.filename).to match(/inventory_report_\d{6}_\d{6}.csv/)
      end

      it 'sends the email to the correct recipient' do
        mail.deliver_now
        expect(mail.to).to eq([product_inv_setting.report_email])
      end
    end
  end

  describe '#auto_inventory_report' do
    let(:mail) { described_class.auto_inventory_report(true, report, nil, tenant) }

    context 'when there are scheduled reports' do
      it 'generates an email with the correct subject' do
        mail.deliver_now
        expect(mail.subject).to eq("Inventory Projection Report [ #{tenant} ]")
      end

      it 'attaches the correct file' do
        mail.deliver_now
        expect(mail.attachments.length).to eq(1)
        expect(mail.attachments.first.filename).to match(/inventory_report_\d{6}_\d{6}.csv/)
      end

      it 'sends the email to the correct recipient' do
        mail.deliver_now
        expect(mail.to).to eq([product_inv_setting.report_email])
      end
    end

    context 'when reports are filtered by ids' do
      let(:report_ids) { [report.id] }
      let(:mail_with_ids) { described_class.auto_inventory_report(true, nil, report_ids, tenant) }

      it 'generates an email for the given report ids' do
        mail_with_ids.deliver_now
        expect(mail_with_ids.attachments.first.filename).to match(/inventory_report_\d{6}_\d{6}.csv/)
      end
    end
  end

  describe '#get_products' do
    context 'when report is All_Products_Report and locked' do
      let(:all_products_report) { ProductInventoryReport.first_or_create(name: 'All_Products_Report', is_locked: true) }

      it 'returns all products' do
        products = inventory_report_mailer.get_products(all_products_report)
        expect(products).to match_array(Product.includes(:product_inventory_warehousess))
      end
    end

    context 'when report is Active_Products_Report and locked' do
      let(:active_products_report) do
        ProductInventoryReport.first_or_create(name: 'Active_Products_Report', is_locked: true)
      end

      it 'returns active products' do
        products = inventory_report_mailer.get_products(active_products_report)
        expect(products).to match_array(Product.includes(:product_inventory_warehousess).where(status: 'active'))
      end
    end

    context 'when report is not locked' do
      it 'returns associated products from the report' do
        products = inventory_report_mailer.get_products(report)
        expect(products).to match_array(report.products.includes(:product_inventory_warehousess))
      end
    end
  end
end
