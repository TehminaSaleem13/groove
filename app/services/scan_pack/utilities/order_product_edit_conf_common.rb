module ScanPack::Utilities::OrderProductEditConfCommon
  def initialize(args)
    @session, @input, @state, @id = args
    @result = {
      "status"=>true,
      "matched"=>false,
      "error_messages"=>[],
      "success_messages"=>[],
      "notice_messages"=>[],
      "data"=>{}
    }
    @single_order = Order.where(id: @id).last
  end
  
  def run(edit_conf_method)
    case true
    when @input.blank? || @id.blank?
      set_error_messages("Please specify confirmation code and order id to confirm purchase code")
    when @single_order.blank?
      set_error_messages("Could not find order with id: "+@id.to_s)
    else
      send(edit_conf_method)
    end
    @result
  end
end