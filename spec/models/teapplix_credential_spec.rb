# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TeapplixCredential, type: :model do
  it 'teapplix credential should belongs to store' do
    teapplix_credential = described_class.reflect_on_association(:store)
    expect(teapplix_credential.macro).to eq(:belongs_to)
  end
end
