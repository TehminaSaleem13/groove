# frozen_string_literal: true

class ServiceInit
  def call(*_args)
    self
  end

  def self.call(*args, **kwargs)
    new(*args, **kwargs).call
  end
end
