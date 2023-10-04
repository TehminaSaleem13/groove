# spec/factories/print_pdf_links.rb
FactoryBot.define do
    factory :print_pdf_link do
      url { "https://example.com/pdf/sample.pdf" }
      is_pdf_printed { false }
      pdf_name { "sample.pdf" }
    end
  end
