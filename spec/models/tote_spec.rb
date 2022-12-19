# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tote, type: :model do
  it 'validates presence of name and must be uniq' do
    tote = described_class.new
    tote.should_not be_valid

    tote = described_class.new(name: 'T1')
    tote.should be_valid

    tote.save
    tote = described_class.new(name: 'T1')
    tote.should_not be_valid
    tote.errors[:name].should include('has already been taken')
  end
end
