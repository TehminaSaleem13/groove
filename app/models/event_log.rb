class EventLog < ApplicationRecord
  belongs_to :user
  serialize :data, Hash
end
