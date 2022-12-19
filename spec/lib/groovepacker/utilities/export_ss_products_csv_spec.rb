# frozen_string_literal: true

require 'rails_helper'

describe ExportSsProductsCsv do
  let(:tenant) { Apartment::Tenant.current }
  let(:inv_wh) { create(:inventory_warehouse, is_default: true) }
  let(:store) { create(:store, inventory_warehouse_id: inv_wh.id) }

  describe '#export_broken_image' do
    let(:params) { { select_all: true } }

    before do
      create(:product, :with_sku_barcode, store_id: store.id)
    end

    it 'delivers email after making list' do
      csv_export_mailer = double
      allow(CsvExportMailer).to receive(:send_s3_broken_image_url).and_return(csv_export_mailer)
      expect(csv_export_mailer).to receive(:deliver)
      subject.export_broken_image(tenant, params)
    end
  end
end
