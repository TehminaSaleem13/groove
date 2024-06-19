# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Groovepacker::Stores::Importers::Teapplix::OrdersImporter do
  Groovepacker::SeedTenant.new.seed
  let(:store) { create(:store, :teapplix) }
  let(:credential) { store.teapplix_credential }
  let(:import_item) { FactoryBot.create(:import_item, store_id: store.id, current_order_imported_item: 0) }
  let(:store_handle) { double('StoreHandle') }
  let(:handler) { { credential: credential, import_item: import_item, store_handle: store_handle } }
  let(:service) { described_class.new(credential) }

  before do
    allow(service).to receive(:get_handler).and_return(handler)
    allow(service).to receive(:update_success_import_count)
  end

  describe '#import_single_order' do
    let(:order_data) do
      {
        "order_source" => "Manual",
        "account" => nil,
        "txn_id" => "Tracking_test",
        "txn_id2" => nil,
        "txn_seq" => "4081",
        "date" => "2024/06/12",
        "status" => "Completed",
        "payment_type" => nil,
        "payment_auth_info" => nil,
        "name" => "Shantal W",
        "payer_email" => "shantal.williams09@gmail.com",
        "contact_phone" => "",
        "address_country" => "United States",
        "address_state" => "FL",
        "address_zip" => "33026",
        "address_city" => "Pembroke Pines",
        "address_street" => "11290 Taft St",
        "address_street2" => "",
        "total" => "0.00",
        "shipping" => "0.00",
        "tax" => "0.00",
        "discount" => "0.00",
        "fee" => "0.00",
        "ship_date" => "2024/06/12",
        "carrier" => "USPS",
        "method" => "GROUNDADV/RECTPARCEL",
        "weight" => "2",
        "tracking" => "TZ984383923224",
        "postage" => nil,
        "postage_account" => nil,
        "num_order_lines" => "1",
        "line_number" => "1",
        "queue_id" => nil,
        "order_tags" => nil,
        "items" => [
          {
            "item_name" => "SADIE-DUP",
            "item_number" => nil,
            "item_sku" => "SADIE-DUP",
            "location" => nil,
            "xref3" => nil,
            "quantity" => "1",
            "subtotal" => "0.00",
            "item_description" => "Sam Edelman Sadie Bright Neon T-Strap Heeled Tassel Sandals - Blue/Gold"
          }
        ]
      }
    end

    context 'when the order should be skipped' do
      it 'do proceed with the import' do
        service.send(:init_common_objects)
        expect { service.send(:import_single_order, order_data) }.to change(Order, :count).by(1)
      end
    end
  end
end