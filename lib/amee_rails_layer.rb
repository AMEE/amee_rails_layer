require 'rubygems'
require 'active_record'
require 'amee'
require 'amee_rails_layer/amee_carbon_store'
require 'amee_rails_layer/amee_category'
require 'amee_rails_layer/unit'

ActiveRecord::Base.class_eval do
  include AmeeCarbonStore
end