class Host < ActiveRecord::Base
    has_many :usage_entries
end
