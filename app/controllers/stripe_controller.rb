class StripeController < ApplicationController
 	# protect_from_forgery :except => :webhook
  def webhook
	  event_json = JSON.parse(request.body.read)
	  # Webhook.create(event: event_json) 
	  # Verify the event by fetching it from Stripe
	  event = Stripe::Event.retrieve(event_json["id"])
	  Webhook.create(event: event) 
	  # Do something with event
	  if event.type == 'invoice.created'
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
	    if !event.data.object.lines.data.first.nil?
	    	invoice.plan_id = event.data.object.lines.data.first.plan.id
		    invoice.period_start = Time.at(event.data.object.lines.data.first.period.start).utc
		    invoice.period_end = Time.at(event.data.object.lines.data.first.period.end).utc
		    invoice.amount = event.data.object.lines.data.first.amount.to_f/100
		    invoice.quantity = event.data.object.lines.data.first.quantity
	    end
	    invoice.save
	    StripeInvoiceEmail.send_invoice(invoice, Apartment::Tenant.current_tenant).deliver
	  end

	  if event.type == 'charge.succeeded'
	    # amount has been deducted from account
	    # customer_id = event_json.data.object.customer
	    # transaction_id = event_json.data.object.balance_transaction
	    # amount = event_json.data.object.amount
	  end

	  if event.type == 'charge.failed'
	    # the charge couldnot be completed due to some error.
	    # customer_id = event_json.data.object.customer
	    # transaction_id = event_json.data.object.balance_transaction
	    # amount = event_json.data.object.amount
	    # error = event_json.data.object.failure_message
	  end

	  if event.type == 'invoice.payment_succeeded'
	    # customer_id = event_json.object.customer
	    # subscription_id = event_json.object.line.data.first.id
	    # subscription_upto = event_json.object.line.data.first.period.end
	    # plan = event_json.object.line.data.first.plan.id
	    # amount = event_json.object.line.data.first.plan.amount
	    # subscription = Subscription.where(customer_subscription_id: subscription_id).first
	    # subscription.is_active = true
	    # subscription.save
	  end

	  if event.type == 'customer.created'
	  	# customer_id = event_json.data.object.id
	  	# if !event_json.data.object.subscription.data.first.nil?
		  # 	subscription_id = event_json.data.object.subscription.data.first.id
		  # 	plan_name = event_json.data.object.subscription.data.first.plan.name
		  # 	plan_interval = event_json.data.object.subscription.data.first.plan.interval
		  # 	amount = event_json.data.object.subscription.data.first.plan.amount
		  # 	trial_period_days = event_json.data.object.subscription.data.first.plan.trial_period_days
		  # 	trial_end = event_json.data.object.subscription.data.first.trial_end
		  # end
	  end

	  if event.type == 'customer.subscription.trial_will_end'
	  	#occurs three days before the trial period of a subscription is scheduled to end.

	  end

	  if event.type == 'customer.subscription.updated'
	    
	  end

	  if event.type == 'customer.subscription.created'
	    # customer_id = event_json.object.customer
	    # subscription_id = event_json.object.id
	    # plan = event_json.object.plan.id
	    # amount = event_json.object.plan.amount
	    # trial_days = event_json.object.plan.trial_period_days
	    # trial_upto = event_json.object.trial_end
	  end

	  status 200
  end
end