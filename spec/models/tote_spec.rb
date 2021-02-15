require 'rails_helper'

RSpec.describe Tote, type: :model do
  it 'should validate presence of name and must be uniq' do
    tote = Tote.new
    tote.should_not be_valid

    tote = Tote.new(name: 'T1')
    tote.should be_valid

    tote.save
    tote = Tote.new(name: 'T1')
    tote.should_not be_valid
    tote.errors[:name].should include('has already been taken')
  end
end
