class CostCalculatorMailer < ActionMailer::Base
  default from: "app@groovepacker.com"

  def send_cost_calculation(params) 
  	follow_up_email = params[:follow_up_email]
  	recipients = [params[:recipient_one], params[:recipient_two], params[:recipient_three]]	
  	@object_url = "admin.#{ENV['HOST_NAME']}/cost_calculator?" + URI.encode(params.except!("controller", "action", "cost_calculator", "recipient_one", "recipient_two" , "recipient_three", "recipient_four", "follow_up_email").to_query)
  	subject = "Cost Calculator Export Report."
    mail to: recipients, subject: subject if !(recipients.all? &:blank?)
  end
end