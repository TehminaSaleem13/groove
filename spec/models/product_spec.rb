# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Product, type: :model do
  describe Product do
    it 'product should belongs to store' do
      t = described_class.reflect_on_association(:store)
      expect(t.macro).to eq(:belongs_to)
    end
  end

  describe Product do
    it " product should have many product's skus" do
      t = described_class.reflect_on_association(:product_skus)
      expect(t.macro).to eq(:has_many)
    end
  end

  describe Product do
    it "Product should have many  product's cats" do
      t = described_class.reflect_on_association(:product_cats)
      expect(t.macro).to eq(:has_many)
    end
  end

  describe Product do
    it "product should have many  product's barcodes" do
      t = described_class.reflect_on_association(:product_barcodes)
      expect(t.macro).to eq(:has_many)
    end
  end

  describe Product do
    it "product should have many product's images" do
      t = described_class.reflect_on_association(:product_images)
      expect(t.macro).to eq(:has_many)
    end
  end

  describe Product do
    it "Product should have many  product kit's skuss" do
      t = described_class.reflect_on_association(:product_kit_skuss)
      expect(t.macro).to eq(:has_many)
    end
  end

  describe Product do
    it "Product should have many  product inventory's warehousess" do
      t = described_class.reflect_on_association(:product_inventory_warehousess)
      expect(t.macro).to eq(:has_many)
    end
  end

  describe Product do
    it 'Product should have many  order items' do
      t = described_class.reflect_on_association(:order_items)
      expect(t.macro).to eq(:has_many)
    end
  end

  describe Product do
    it 'Product should have many  product kit activities' do
      t = described_class.reflect_on_association(:product_kit_activities)
      expect(t.macro).to eq(:has_many)
    end
  end

  describe Product do
    it 'Product should have many  product lots' do
      t = described_class.reflect_on_association(:product_lots)
      expect(t.macro).to eq(:has_many)
    end
  end

  describe Product do
    it 'Product should have many  product product inventory reports' do
      t = described_class.reflect_on_association(:product_inventory_reports)
      expect(t.macro).to eq(:has_and_belongs_to_many)
    end
  end

  describe Product do
    it 'Product should have one sync option' do
      t = described_class.reflect_on_association(:sync_option)
      expect(t.macro).to eq(:has_one)
    end
  end

  describe Product do
    it 'Product should have many  product activities' do
      t = described_class.reflect_on_association(:product_activities)
      expect(t.macro).to eq(:has_many)
    end
  end
end
