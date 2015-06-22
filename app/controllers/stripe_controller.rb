	class StripeController < ApplicationController
	 	protect_from_forgery :except => :webhook
	 	def webhook
	 		event_json = JSON.parse(request.body.read)
		  # Webhook.create(event: event_json) 
		  # Verify the event by fetching it from Stripe
		  event = Stripe::Event.retrieve(event_json["id"])
		  Apartment::Tenant.switch()
		  if Webhook.create(event: event)
		  	logger.info("event saved as blob") 
		  end
		  # Do something with event
		  if event.type == 'invoice.created'
		  	logger.info("in event type invoice.created")
		  elsif event.type == 'charge.succeeded'
		  	logger.info("in event type charge.succeeded")
		  elsif event.type == 'charge.failed'
		  	logger.info("in event type charge.failed")
		  elsif event.type == 'invoice.payment_succeeded'
		  	logger.info("in event type invoice.payment_succeeded")
		  	@invoice = get_invoice(event)
		  	if @invoice.save
		  		logger.info("saved the invoice for event invoice.created")
		  		StripeInvoiceEmail.send_success_invoice(@invoice).deliver
		  	end
		  	ApplyAccessRestrictions.apply_access_restrictions(@invoice) unless @invoice.plan_id.nil?
		  elsif event.type == 'invoice.payment_failed'
		  	logger.info("in event type invoice.payment_failed")
		  	@invoice = get_invoice(event)
		  	if @invoice.save
		  		logger.info("saved the invoice for event invoice.created")
		  		StripeInvoiceEmail.send_failure_invoice(@invoice).deliver
		  	end
		  elsif event.type == 'customer.created'
		  	logger.info("in event type customer.created")
			elsif event.type == 'customer.subscription.trial_will_end'
		  	#occurs three days before the trial period of a subscription is scheduled to end.

		  elsif event.type == 'customer.subscription.updated'
		    #customer updates the subscription
		  elsif event.type == 'customer.subscription.created'
		  	logger.info("in event type customer.subscription.created")
		  end
		  render :status => 200, :nothing => true
		end
		def get_invoice(event)
			invoice = Invoice.new
	  	invoice.date = Time.at(event.data.object.date).utc
	  	invoice.invoice_id = event.data.object.id
	  	invoice.subscription_id = event.data.object.subscription
	  	invoice.customer_id = event.data.object.customer
	  	invoice.charge_id = event.data.object.charge
	  	invoice.attempted = event.data.object.attempted
	  	invoice.closed = event.data.object.closed
	  	invoice.forgiven = event.data.object.forgiven
	  	invoice.paid = event.data.object.paid
	  	unless event.data.object.lines.data.first.nil?
	  		invoice.plan_id = event.data.object.lines.data.first.plan.id unless event.data.object.lines.data.first.plan.id.nil? || event.data.object.lines.data.first.plan.nil?
	  		invoice.period_start = Time.at(event.data.object.lines.data.first.period.start).utc
	  		invoice.period_end = Time.at(event.data.object.lines.data.first.period.end).utc
	  		if event.data.object.starting_balance == 0
	  			invoice.amount = event.data.object.lines.data.first.amount.to_f/100
	  		else
	  			invoice.amount = event.data.object.starting_balance.to_f/100
	  		end
	  		invoice.quantity = event.data.object.lines.data.first.quantity unless event.data.object.lines.data.first.quantity.nil?
	  	end
	  	invoice
		end
	end