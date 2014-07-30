require "json"

post "/my/webhook/url" do
  # Retrieve the request's body and parse it as JSON
  event_json = JSON.parse(request.body.read)

  # Verify the event by fetching it from Stripe
  event = Stripe::Event.retrieve(event_json["id"])

  # Do something with event
  if event == invoice.created
    subscription_id = event_json.object.line.data.first.id
    customer_id = event_json.object.customer
    plan = event_json.object.line.data.first.plan.id
    subscription_upto = event_json.object.period_end
    amount = event_json.object.data.first.amount
  end

  if event == charge.succeeded

  end

  if event == charge.failed

  end

  if event == invoice.payment_succeeded
    customer_id = event_json.object.customer
    subscription_id = event_json.object.line.data.first.id
    subscription_upto = event_json.object.line.data.first.period.end
    plan = event_json.object.line.data.first.plan.id
    amount = event_json.object.line.data.first.plan.amount
    subscription = Subscription.where(customer_subscription_id: subscription_id).first
    subscription.is_active = true
    subscription.save
  end

  if event == customer.subscription.trial_will_end

  end

  if event == customer.subscription.updated
    
  end

  if event == customer.subscription.created
    customer_id = event_json.object.customer
    subscription_id = event_json.object.id
    plan = event_json.object.plan.id
    amount = event_json.object.plan.amount
    trial_days = event_json.object.plan.trial_period_days
    trial_upto = event_json.object.trial_end
  end

  status 200
end