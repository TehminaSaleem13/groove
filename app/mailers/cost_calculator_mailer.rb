class CostCalculatorMailer < ActionMailer::Base
  default from: "app@groovepacker.com"

  def send_cost_calculation(params) 
    @reciepient_name = params["recipient_name"]
  	@body = params["email_text"].gsub("6904.5", params[:monthly_shipping])
  	follow_up_email = params[:follow_up_email]
    recipients = [params[:recipient_one], params[:recipient_two], params[:recipient_three]]	
    emails = []
    recipients.each do |recipient| 
      emails << recipient if recipient != "undefined"   
    end
    @object_url = "http://admin.#{ENV['SHOPIFY_REDIRECT_HOST']}/#/settings/cost_calculator?" + URI.encode(params.except!("controller", "action", "cost_calculator", "recipient_one", "recipient_two" , "recipient_three", "recipient_four", "follow_up_email").to_query)
  	subject = params["recipient_name"].present? ? "Fulfillment error cost calculator / Sent by #{params["recipient_name"]}" : "Fulfillment error cost calculator"
    mail to: emails, subject: subject if !(recipients.all? &:blank?)
  end
end