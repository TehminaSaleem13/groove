class ProductsService::ServiceInit
  require 'barby'
  require 'barby/barcode/code_128'
  require 'barby/outputter/png_outputter'
  require 'mws-connect'

  def call(*_args)
    self
  end

  def self.call(*args)
    new(*args).call
  end
end
