require 'rubygems'
require 'active_record'
require 'amee'

ActiveRecord::Base.class_eval do
  include AmeeCarbonStore
end