# frozen_string_literal: true

FactoryBot.define do
  factory :groovepacker_webhook do
    url { 'http://test.gptest.com/test' }
    event { 'order_scanned' }
    secret_key { '123asa23' }
  end
end
