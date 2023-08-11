# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Groovepacker::Dashboard::Stats::Exception do
  describe "#initialize" do
    context "when user_id is provided" do
      let(:user_id) { 123 }

      it "should initialize instance variables with provided user_id" do
        order_exception = Groovepacker::Dashboard::Stats::Exception.new(user_id)

        expect(order_exception.instance_variable_get(:@user_id)).to eq(user_id)
        expect(order_exception.instance_variable_get(:@exceptions_considered)).to eq(%w[qty_related incorrect_item missing_item damaged_item special_instruction other])
        expect(order_exception.instance_variable_get(:@results)).to eq([])
        expect(order_exception.instance_variable_get(:@exceptions)).to eq([])
      end
    end
  end
end