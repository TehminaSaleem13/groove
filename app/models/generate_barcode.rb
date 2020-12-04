class GenerateBarcode < ActiveRecord::Base
  # attr_accessible :status, :url, :user_id, :current_order_position, :total_orders,
  #                 :next_order_increment_id, :status, :current_increment_id, :print_type, :dimensions
  after_save :emit_data_to_user

  def emit_data_to_user
    GroovRealtime::user_emit('pnotif', {type: 'generate_barcode_status', data: self, post_scanning_option: ScanPackSetting.last.post_scanning_option}, self.user_id)
  end

  def self.generate_barcode_for(orders, current_user)
  	g_barcode = GenerateBarcode.new
    g_barcode.user_id = current_user.id
    g_barcode.current_order_position = 0
    g_barcode.total_orders = orders.length
    g_barcode.next_order_increment_id = orders.first[:increment_id] unless orders.first.nil?
    g_barcode.status = 'scheduled'
    g_barcode.save
    return g_barcode 
  end
end
