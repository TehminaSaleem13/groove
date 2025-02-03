module CartsHelper
  require 'barby/barcode/code_128'
  require 'barby/outputter/html_outputter'
  require 'barby/outputter/png_outputter'

  def generate_barcode_html(value)
    Barby::Code128B.new(value).to_html
  end

  def generate_barcode_png(value)
    barcode = Barby::Code128B.new(value)
    Base64.encode64(barcode.to_png(height: 50, margin: 5))
  end

  def generate_qr_code(value)
    RQRCode::QRCode.new(value).as_svg(module_size: 3)
  end
end
