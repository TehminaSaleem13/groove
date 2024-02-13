# frozen_string_literal: true

FactoryBot.define do
  factory :api_key do
    author { FactoryBot.create(:user) }
  end
end
