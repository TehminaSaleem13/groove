# frozen_string_literal: true

FactoryBot.define do
  factory :tenant do
    name { 'sitetest' }
    duplicate_tenant_id { nil }
  end
end
