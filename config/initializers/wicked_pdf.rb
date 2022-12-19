# frozen_string_literal: true

unless Rails.env.test?
  WickedPdf.config = {
    exe_path: '/usr/local/bin/wkhtmltopdf'
  }
end
