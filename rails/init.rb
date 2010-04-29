require 'amee_rails_layer'

ActiveRecord::Base.class_eval do
  include AmeeCarbonStore
end