# frozen_string_literal: true

def switch_tenant(tenant, &block)
  if block_given?
    Apartment::Tenant.switch(tenant, &block)
  else
    Apartment::Tenant.switch!(tenant)
  end
end

def current_tenant_object
  @current_tenant_object = Tenant.find_by_name(Apartment::Tenant.current)
end
