class ServiceInit
  def call(*_args)
    self
  end

  def self.call(*args)
    new(*args).call
  end
end
