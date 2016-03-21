class StripeController < ApplicationController
  protect_from_forgery except: :webhook

  def webhook
    event_json = JSON.parse(request.body.read)
    # Webhook.create(event: event_json)
    # Verify the event by fetching it from Stripe
    event = Stripe::Event.retrieve(event_json['id'])
    Apartment::Tenant.switch
    Webhook.create(event: event)
    type = event.type
    if ['invoice.payment_succeeded', 'invoice.payment_failed'].include? type
      @invoice = get_invoice(event)
      case type
      when 'invoice.payment_succeeded'
        StripeInvoiceEmail.send_success_invoice(@invoice).deliver
      when 'invoice.payment_failed'
        StripeInvoiceEmail.send_failure_invoice(@invoice).deliver
      end
    end
    render status: 200, nothing: true
  end

  def get_invoice(event)
    invoice = Invoice.new
    object = event.data.object
    invoice.date = time_utc(object.date)
    invoice.invoice_id = object.id
    invoice.subscription_id = object.subscription
    invoice.customer_id = object.customer
    invoice.charge_id = object.charge
    invoice.attempted = object.attempted
    invoice.closed = object.closed
    invoice.forgiven = object.forgiven
    invoice.paid = object.paid
    @line_data = object.lines.data.first
    if @line_data
      @plan = @line_data.plan
      invoice.plan_id = @plan.id if @plan && @plan.id
      @period = @line_data.period
      invoice.period_start = time_utc(@period.start)
      invoice.period_end = time_utc(@period.end)
      if object.starting_balance == 0
        invoice.amount = @line_data.amount.to_f / 100
      else
        invoice.amount = object.starting_balance.to_f / 100
      end
      invoice.quantity = @line_data.quantity if @line_data.quantity
    end
    invoice.save!
    invoice
  end

  private

  def time_utc(time)
    Time.at(time).utc
  end
end
