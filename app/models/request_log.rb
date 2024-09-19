# frozen_string_literal: true

class RequestLog < ApplicationRecord
  include Encryptable

  def payload
    decrypt_and_decompress(request_body)
  rescue StandardError
  end
end
