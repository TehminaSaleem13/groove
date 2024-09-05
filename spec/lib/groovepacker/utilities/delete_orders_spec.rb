# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeleteOrders do
  let(:inv_wh) { create(:inventory_warehouse, name: 'csv_inventory_warehouse') }
  let!(:store) { create(:store, name: 'csv_store', store_type: 'CSV', inventory_warehouse: inv_wh, status: true) }

  before do
    tenant = Apartment::Tenant.current
    Tenant.create(name: tenant.to_s)
  end

  describe '#delete_tenant_orders' do
    it 'delete awaiting orders' do
      order = create(:order, store:)
      product = create(:product, name: 'PRODUCT', store:)
      create(:product_sku, product_id: product.id, sku: 'PRODUCT-SKU')
      create(:product_barcode, product_id: product.id, barcode: 'PRODUCT-BARCODE')
      kit = create(:product, is_kit: 1, kit_parsing: 'individual', name: 'KIT', store:)
      create(:product_sku, product_id: kit.id, sku: 'KIT-SKU')
      create(:product_barcode, product_id: kit.id, barcode: 'KIT-BARCODE')
      productkitsku = create(:product_kit_sku, product_id: product.id, option_product_id: kit.id, qty: 1)
      order_item = create(:order_item, sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id,
                                       name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product.id, scanned_status: 'notscanned', scanned_qty: 0, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      order_item1 = create(:order_item, sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id,
                                        name: 'TRIGGER SS JERSEY-BLACK-M', product_id: kit.id, scanned_status: 'notscanned', scanned_qty: 0, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      create(:order_item_kit_product, order_item_id: order_item1.id, product_kit_skus_id: productkitsku.id,
                                      scanned_status: 'unscanned', scanned_qty: 0)

      # create awaiting order with 15 days ago date
      order1 = create(:order, increment_id: 'testkkk', store_id: store.id, created_at: 15.days.ago,
                              updated_at: 15.days.ago)
      product1 = create(:product, name: 'PRODUCT1', store:)
      create(:product_sku, product_id: product1.id, sku: 'PRODUCT1-SKU')
      create(:product_barcode, product_id: product.id, barcode: 'PRODUCT1-BARCODE')
      kit1 = create(:product, is_kit: 1, kit_parsing: 'individual', name: 'KIT1', store:)
      create(:product_sku, product_id: kit1.id, sku: 'KIT1-SKU')
      create(:product_barcode, product_id: kit1.id, barcode: 'KIT1-BARCODE')
      productkitsku1 = create(:product_kit_sku, product_id: product1.id, option_product_id: kit1.id, qty: 1)
      order_item2 = create(:order_item, sku: nil, qty: 1, price: nil, row_total: 0, order_id: order1.id,
                                        name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product1.id, scanned_status: 'notscanned', scanned_qty: 0, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      order_item3 = create(:order_item, sku: nil, qty: 1, price: nil, row_total: 0, order_id: order1.id,
                                        name: 'TRIGGER SS JERSEY-BLACK-M', product_id: kit1.id, scanned_status: 'notscanned', scanned_qty: 0, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      create(:order_item_kit_product, order_item_id: order_item3.id, product_kit_skus_id: productkitsku1.id,
                                      scanned_status: 'unscanned', scanned_qty: 0)

      described_class.new.perform

      expect(Order.all.count).to eq(1)
      expect(OrderItem.all.count).to eq(2)
      expect(OrderItemKitProduct.all.count).to eq(1)
      expect(Product.all.count).to eq(4)
      expect(ProductKitSkus.all.count).to eq(2)
      expect(ProductSku.all.count).to eq(4)
      expect(ProductBarcode.all.count).to eq(4)
    end

    it 'delete onhold orders' do
      # create onhold order with current date
      order = create(:order, store_id: store.id)
      product = create(:product, name: 'PRODUCT', store:)
      create(:product_sku, product_id: product.id, sku: 'PRODUCT-SKU')
      create(:product_barcode, product_id: product.id, barcode: 'PRODUCT-BARCODE')
      kit = create(:product, is_kit: 1, kit_parsing: 'individual', name: 'KIT', store:)
      create(:product_sku, product_id: kit.id, sku: 'KIT-SKU')
      create(:product_barcode, product_id: kit.id, barcode: 'KIT-BARCODE')
      productkitsku = create(:product_kit_sku, product_id: product.id, option_product_id: kit.id, qty: 1)
      order_item = create(:order_item, sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id,
                                       name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product.id, scanned_status: 'notscanned', scanned_qty: 0, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      order_item1 = create(:order_item, sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id,
                                        name: 'TRIGGER SS JERSEY-BLACK-M', product_id: kit.id, scanned_status: 'notscanned', scanned_qty: 0, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      create(:order_item_kit_product, order_item_id: order_item1.id, product_kit_skus_id: productkitsku.id,
                                      scanned_status: 'unscanned', scanned_qty: 0)

      # create onhold order with 15 days ago date
      order1 = create(:order, increment_id: 'testkkk', status: 'onhold', store_id: store.id, created_at: 15.days.ago,
                              updated_at: 15.days.ago)
      product1 = create(:product, name: 'PRODUCT1', store:)
      create(:product_sku, product_id: product1.id, sku: 'PRODUCT1-SKU')
      create(:product_barcode, product_id: product.id, barcode: 'PRODUCT1-BARCODE')
      kit1 = create(:product, is_kit: 1, kit_parsing: 'individual', name: 'KIT1', store:)
      create(:product_sku, product_id: kit1.id, sku: 'KIT1-SKU')
      create(:product_barcode, product_id: kit1.id, barcode: 'KIT1-BARCODE')
      productkitsku1 = create(:product_kit_sku, product_id: product1.id, option_product_id: kit1.id, qty: 1)
      order_item2 = create(:order_item, sku: nil, qty: 1, price: nil, row_total: 0, order_id: order1.id,
                                        name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product1.id, scanned_status: 'notscanned', scanned_qty: 0, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      order_item3 = create(:order_item, sku: nil, qty: 1, price: nil, row_total: 0, order_id: order1.id,
                                        name: 'TRIGGER SS JERSEY-BLACK-M', product_id: kit1.id, scanned_status: 'notscanned', scanned_qty: 0, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      create(:order_item_kit_product, order_item_id: order_item3.id, product_kit_skus_id: productkitsku1.id,
                                      scanned_status: 'unscanned', scanned_qty: 0)

      described_class.new.perform

      expect(Order.all.count).to eq(1)
      expect(OrderItem.all.count).to eq(2)
      expect(OrderItemKitProduct.all.count).to eq(1)
      expect(Product.all.count).to eq(4)
      expect(ProductKitSkus.all.count).to eq(2)
      expect(ProductSku.all.count).to eq(4)
      expect(ProductBarcode.all.count).to eq(4)
    end

    it 'delete 90 days ago partically scanned orders' do
      # create partically scanned order with current date
      order = create(:order, store_id: store.id)
      product = create(:product, name: 'PRODUCT', store:)
      create(:product_sku, product_id: product.id, sku: 'PRODUCT-SKU')
      create(:product_barcode, product_id: product.id, barcode: 'PRODUCT-BARCODE')
      kit = create(:product, is_kit: 1, kit_parsing: 'individual', name: 'KIT', store:)
      create(:product_sku, product_id: kit.id, sku: 'KIT-SKU')
      create(:product_barcode, product_id: kit.id, barcode: 'KIT-BARCODE')
      productkitsku = create(:product_kit_sku, product_id: product.id, option_product_id: kit.id, qty: 1)
      order_item = create(:order_item, sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id,
                                       name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product.id, scanned_status: 'scanned', scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      order_item1 = create(:order_item, sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id,
                                        name: 'TRIGGER SS JERSEY-BLACK-M', product_id: kit.id, scanned_status: 'notscanned', scanned_qty: 0, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      create(:order_item_kit_product, order_item_id: order_item1.id, product_kit_skus_id: productkitsku.id,
                                      scanned_status: 'unscanned', scanned_qty: 0)

      # create partically scanned order with 95 days ago date
      order1 = create(:order, increment_id: 'testkkk', store_id: store.id, created_at: 95.days.ago,
                              updated_at: 95.days.ago)
      product1 = create(:product, name: 'PRODUCT1', store:)
      create(:product_sku, product_id: product1.id, sku: 'PRODUCT1-SKU')
      create(:product_barcode, product_id: product.id, barcode: 'PRODUCT1-BARCODE')
      kit1 = create(:product, is_kit: 1, kit_parsing: 'individual', name: 'KIT1', store:)
      create(:product_sku, product_id: kit1.id, sku: 'KIT1-SKU')
      create(:product_barcode, product_id: kit1.id, barcode: 'KIT1-BARCODE')
      productkitsku1 = create(:product_kit_sku, product_id: product1.id, option_product_id: kit1.id, qty: 1)
      order_item2 = create(:order_item, sku: nil, qty: 1, price: nil, row_total: 0, order_id: order1.id,
                                        name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product1.id, scanned_status: 'scanned', scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      order_item3 = create(:order_item, sku: nil, qty: 1, price: nil, row_total: 0, order_id: order1.id,
                                        name: 'TRIGGER SS JERSEY-BLACK-M', product_id: kit1.id, scanned_status: 'notscanned', scanned_qty: 0, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      create(:order_item_kit_product, order_item_id: order_item3.id, product_kit_skus_id: productkitsku1.id,
                                      scanned_status: 'unscanned', scanned_qty: 0)

      described_class.new.perform

      expect(Order.all.count).to eq(1)
      expect(OrderItem.all.count).to eq(2)
      expect(OrderItemKitProduct.all.count).to eq(1)
      expect(Product.all.count).to eq(4)
      expect(ProductKitSkus.all.count).to eq(2)
      expect(ProductSku.all.count).to eq(4)
      expect(ProductBarcode.all.count).to eq(4)
    end

    it 'delete 90 days ago scanned orders' do
      # create scanned order with current date
      order = create(:order, store_id: store.id, status: 'scanned', created_at: 15.days.ago, updated_at: 15.days.ago,
                             scanned_on: 15.days.ago)
      product = create(:product, name: 'PRODUCT', store:)
      create(:product_sku, product_id: product.id, sku: 'PRODUCT-SKU')
      create(:product_barcode, product_id: product.id, barcode: 'PRODUCT-BARCODE')
      kit = create(:product, is_kit: 1, kit_parsing: 'individual', name: 'KIT', store:)
      create(:product_sku, product_id: kit.id, sku: 'KIT-SKU')
      create(:product_barcode, product_id: kit.id, barcode: 'KIT-BARCODE')
      productkitsku = create(:product_kit_sku, product_id: product.id, option_product_id: kit.id, qty: 1)
      order_item = create(:order_item, sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id,
                                       name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product.id, scanned_status: 'scanned', scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      order_item1 = create(:order_item, sku: nil, qty: 1, price: nil, row_total: 0, order_id: order.id,
                                        name: 'TRIGGER SS JERSEY-BLACK-M', product_id: kit.id, scanned_status: 'scanned', scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      create(:order_item_kit_product, order_item_id: order_item1.id, product_kit_skus_id: productkitsku.id,
                                      scanned_status: 'unscanned', scanned_qty: 0)

      # create scanned order with 95 days ago date
      order1 = create(:order, increment_id: 'testkkk', status: 'scanned', store_id: store.id, created_at: 95.days.ago,
                              updated_at: 95.days.ago, scanned_on: 95.days.ago)
      product1 = create(:product, name: 'PRODUCT1', store:)
      create(:product_sku, product_id: product1.id, sku: 'PRODUCT1-SKU')
      create(:product_barcode, product_id: product.id, barcode: 'PRODUCT1-BARCODE')
      kit1 = create(:product, is_kit: 1, kit_parsing: 'individual', name: 'KIT1', store:)
      create(:product_sku, product_id: kit1.id, sku: 'KIT1-SKU')
      create(:product_barcode, product_id: kit1.id, barcode: 'KIT1-BARCODE')
      productkitsku1 = create(:product_kit_sku, product_id: product1.id, option_product_id: kit1.id, qty: 1)
      order_item2 = create(:order_item, sku: nil, qty: 1, price: nil, row_total: 0, order_id: order1.id,
                                        name: 'TRIGGER SS JERSEY-BLACK-M', product_id: product1.id, scanned_status: 'scanned', scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      order_item3 = create(:order_item, sku: nil, qty: 1, price: nil, row_total: 0, order_id: order1.id,
                                        name: 'TRIGGER SS JERSEY-BLACK-M', product_id: kit1.id, scanned_status: 'scanned', scanned_qty: 1, kit_split: false, kit_split_qty: 0, kit_split_scanned_qty: 0, single_scanned_qty: 0, inv_status: 'unprocessed', inv_status_reason: '', clicked_qty: 1, is_barcode_printed: false, is_deleted: false, box_id: nil, skipped_qty: 0)
      create(:order_item_kit_product, order_item_id: order_item3.id, product_kit_skus_id: productkitsku1.id,
                                      scanned_status: 'unscanned', scanned_qty: 0)

      described_class.new.perform

      expect(Order.all.count).to eq(1)
      expect(OrderItem.all.count).to eq(2)
      expect(OrderItemKitProduct.all.count).to eq(1)
      expect(Product.all.count).to eq(4)
      expect(ProductKitSkus.all.count).to eq(2)
      expect(ProductSku.all.count).to eq(4)
      expect(ProductBarcode.all.count).to eq(4)
    end
  end
end
