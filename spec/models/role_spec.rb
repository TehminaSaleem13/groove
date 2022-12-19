# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Role, type: :model do
  describe 'presence of name' do
    it 'role must have name' do
      role = described_class.create(name: '')
      role.valid?
      role.errors.should have_key(:name)
    end
  end

  describe Role do
    it 'role should have uniq name' do
      described_class.create(name: 'admin')
      role = described_class.create(name: 'admin')
      expect(role).not_to be_valid
    end
  end

  it 'role  have many users' do
    role = described_class.reflect_on_association(:users)
    expect(role.macro).to eq(:has_many)
  end
end
