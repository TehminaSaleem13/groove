class SubscriptionsController < ApplicationController
  def payment
  	Apartment::Tenant.switch()
  	@subscription = Subscription.new
  end
  def select_plan
  	
  end
  def collect_information
  	
  end
end
