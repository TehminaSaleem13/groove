class PriorityCard < ApplicationRecord
    validates :priority_name, presence: true, uniqueness: true
    validates :assigned_tag, uniqueness: true
end
  