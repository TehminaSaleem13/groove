module ProductsService
  class Base < ServiceInit
    require 'barby'
    require 'barby/barcode/code_128'
    require 'barby/outputter/png_outputter'
    require 'mws-connect'
  end
end
