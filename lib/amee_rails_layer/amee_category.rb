require 'amee_rails_layer/unit'

# Encapsulates information on the AMEE category used to store data against.  For example, in an 
# application modelling Car Trips the model would have an AmeeCategory representing the chosen Car
# Category in AMEE.  In an application with a more generic Journey model with multiple possible 
# types, the Journey model would have an AmeeCategory for each type that Journey could take - ie 
# Car, Bus, Van...  In all cases the model will need the amee_category method to return the correct
# AmeeCategory object as described in AmeeCarbonStore.  See the README for more information on the
# application structure this gem assumes and examples of how to use it.
#
# There are several types the AmeeCategory can be constructed with:
# * :distance - the total distance (units available are km or mile)
# * :journey_distance - the distance of the journey (units available are km or miles)
# * :weight - the total weight (units available are kg or tonned)
# * :energy - the energy consumed (units available are kWh)
# * :volumable_energy - the energy consumed specified either as a volume of fuel or energy unit 
#   (units available are litres or kWh)
#
# The CATEGORY_TYPES constant maps these symbols to the corresponding field names used in amee to
# store the amount of whatever is being specified.  So for a given data item path you must ensure
# the item value supports the field named there.  For example: assuming we've gone with 
# :journey_distance as the type and a path of /transport/bus/generic/defra then this would work as 
# the amount of miles is specified in the distancePerJourney field in amee.  For 
# /transport/car/generic/defra/bysize however it would not work as the only available field in amee
# is distance (so the type :distance must be used).
#
# The type also determines the units that instances of the model can be created with.  The available 
# units are specified in the constant CATEGORY_TYPES_TO_UNITS but are also listed in the bullets
# above above for convience.  Developers can provide additional units by (manually) passing in a 
# unit conversion factor in the constructor. See the constructor documentation for more on how to
# do this.
class AmeeCategory
  
  attr_accessor :name, :path
  
  CATEGORY_TYPES = {
    :distance => [:distance],
    :journey_distance => [:distancePerJourney],
    :weight => [:mass],
    :energy => [:energyConsumption],
    :volumable_energy => [:volumePerTime, :energyConsumption]
  }

  CATEGORY_TYPES_TO_UNITS = {
    :distance => [Unit.km, Unit.miles],
    :distancePerJourney => [Unit.km, Unit.miles],
    :mass => [Unit.kg, Unit.tonnes],
    :energyConsumption => [Unit.kwh],
    :volumePerTime => [Unit.litres],
  }
  
  # Create an AmeeCategory.  The initializer takes the following parameters:
  # * name - a human readable name to refer to the category by.  This is not used in the storing or
  #   retrieving of data in amee but is useful for exposing in the view where a user chooses the 
  #   type they would like for the model
  # * category_type - either :distance, :journey_distance, :weight, :energy or :volumable_energy.  See 
  #   notes in class header for more on this
  # * profile_category_path - the path to the amee category - eg "/transport/car/generic/defra/bysize"
  # * options - any additional options required with the profile_category_path to make the path 
  #   refer to just one amee categorgy (typically these are passed in as a query string URL in amee 
  #   explorer).  For example: {:fuel => "average", :size => "average"}
  #   
  #   This option can also take an optional hash for unit conversions, for example:
  #     :unit_conversions => {:kg => [:m3 => 2.5, :abc => 0.3], :xyz => [:efg => 0.6]}
  #   which would make m3 available as a unit (converted to kg by * 2.5).  The hash keys, :kg and 
  #   :xyz in this case, must map to the unit types provided by the corresponding category_type 
  #   option - ie :kg would work if this option was :weight but not :energy
  def initialize(name, category_type, profile_category_path, options = {}, *args)
    @name = name
    @category_type = category_type
    @path = profile_category_path
    @conversions = options.delete(:unit_conversions)
    @path_options = options
  end
  
  # The drill down path as derived from the path and options arguments in the constructor
  def drill_down_path
    "/data#{@path}/drill?#{@path_options.to_query}"
  end

  # Returns an array of the available unit names and amee api unit string representations.  This
  # will also include any units provided by the user through the unit_conversions option.  The
  # resulting array can be passed straight through to a options_for_select view helper.
  #
  # For example if the instance is constructed with the :weight category_type option then this 
  # will produce: [["kg", "kg"], ["tonnes", "t"]]
  def unit_options
    unit_options = category_units.map{|unit| [unit.name, unit.amee_api_unit]}
    unit_options += alternative_unit_options if has_alternative_units?
    unit_options
  end

  # Given an AMEE API unit string return the category type
  def category_type_from_amee_api_unit(amee_unit)
    category_types.each do |type|
      return type if amee_api_units(type).include?(amee_unit)
    end
    return nil
  end
  
  # For a given unit returns true if the passed unit is an alternative one - ie conversion
  # factor supplied by user in the constructor
  def has_alternative_unit?(unit)
    return false unless has_alternative_units?    
    units = @conversions.values.map(&:first).map(&:keys).flatten
    units.include?(unit.to_sym)
  end
  
  # Given an alternative unit, returns the units it converts to
  def alternative_unit_converts_to(unit_name)
    units_to_alternates = merge_hashes(@conversions.map {|k,v| {k => v.first.keys}})
    units_to_alternates.each do |amee_unit, alt_units|
      return amee_unit if alt_units.include?(unit_name.to_sym)
    end
    return nil
  end
  
  # Given an alternative unit, returns the factor needed to convert it to the unit it
  # can be derived from
  def alternative_unit_conversion_factor(unit_name)
    alternative_units_to_conversions.each do |alt_unit, conversion|
      return conversion if alt_unit == unit_name.to_sym
    end
    return nil
  end
  
  private
  def category_types
    CATEGORY_TYPES[@category_type]
  end
  
  def category_units
    category_types.map{|t| CATEGORY_TYPES_TO_UNITS[t]}.flatten
  end
  
  def has_alternative_units?
    !@conversions.nil?
  end
  
  def amee_api_units(name)
    CATEGORY_TYPES_TO_UNITS[name].map{|u| u.amee_api_unit}
  end
  
  def alternative_units_to_conversions
    merge_hashes(@conversions.map {|k,v| v.first})
  end
  
  def alternative_unit_options
    alternative_units_to_conversions.keys.map {|unit| [unit.to_s, unit.to_s]}
  end
  
  # Does [{:a => 1, :b => 2}, {:c => 3}, {:d => 4}]  to  {:a => 1, :b => 2, :c => 3, :d => 4}
  def merge_hashes(array_of_hashes)
    result = {}
    array_of_hashes.each do |item|
      item.keys.each do |k|
        result[k] = item[k]
      end
    end
    result
  end
end