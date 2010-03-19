# Encapsulates the Units used by the AMEE API.  Possible types are currently
# :km, :miles, :kg, :tonnes, :kwh, :litres and :uk_gallons  Convience class
# methods are provided to construct an object of each of these types
class Unit

  NAME = {
    :km => "km",
    :miles => "miles",
    :kg => "kg",
    :tonnes => "tonnes",
    :kwh => "kWh",
    :litres => "litres",
    :uk_gallons => "UK Gallons"
  }

  AMEE_API_UNITS = {
    :km => "km",
    :miles => "mi",
    :kg => "kg",
    :tonnes => "t",
    :kwh => "kWh",
    :litres => "L",
    :uk_gallons => "gal_uk"
  }

  # Creates a new Unit object from the symbol representing the unit (see class doc)
  def initialize(type, *args)
    @type = type
  end
  
  # Creates a new Unit class from the string used by AMEE to represent the unit.  For example
  # pass in "t" to initialize an Unit object for tonnes
  def self.from_amee_unit(unit)
    AMEE_API_UNITS.each do |key, value|
      return new(key) if value == unit
    end
    return nil
  end
  
  # A human readable form of the unit
  def name
    NAME[@type]
  end
  
  # The string used by the AMEE API to represent the unit
  def amee_api_unit
    AMEE_API_UNITS[@type]
  end
  
  def self.km
    new(:km)
  end
  
  def self.miles
    new(:miles)
  end
  
  def self.kg
    new(:kg)
  end
  
  def self.tonnes
    new(:tonnes)
  end
  
  def self.kwh
    new(:kwh)
  end
  
  def self.litres
    new(:litres)
  end
  
  def self.uk_gallons
    new(:uk_gallons)
  end
end