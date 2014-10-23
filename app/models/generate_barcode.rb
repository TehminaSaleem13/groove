class GenerateBarcode < ActiveRecord::Base
  attr_accessible :status, :url
  after_save :emit_data_to_user

  def emit_data_to_user
    GroovRealtime::user_emit('pnotif',{type:'generate_barcode_status',data:self},self.user_id)
  end
end
