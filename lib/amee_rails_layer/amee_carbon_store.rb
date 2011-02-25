# Module that abstracts some common patterns for data storage/retrieval in AMEE.  This is 
# automatically included in ActiveRecord::Base object when used with Rails.  See the gem
# README for more information on the application structure this gem assumes.
# 
# Classes that have the has_carbon_data_stored_in_amee decleartion require the following
# database columns:
# * name (string) - a name for the object, often set by user but can be assigned automatically
# * amee_profile_item_id (string) - the AMEE profile Item ID used to store the carbon data
# * carbon_output_cache (float) - the amount of carbon produced
# * units (string) - the units the amount field is in
# * amount (float) - the amount of the thing being recorded, eg 6 (kg), 9 (litres)
# * amee_profile (string) - optional.  The amee profile identifier under which all the data
#   is stored.  Although this field is optional, if it is not present then a Proc must be 
#   passed to the has_carbon_data_stored_in_amee decleration evaluating to an amee profile
# * repetitions (integer) - optional.  Used when the model object is composed of several
#   repetitions - for example 6 x 3 miles would make the repetitions 6  
# * start_date (date) - optional.  Used in combination with the has_date_range option on
#   has_carbon_data_stored_in_amee to store the start date for the data
# * end_date (date) - optional.  Used in combination with the has_date_range option on
#   has_carbon_data_stored_in_amee to store the end date for the data
module AmeeCarbonStore
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    # Class method that configures a class for storing carbon data in amee.  Options are as follows:
    # * profile - if set will use this Proc to access the amee profile used to store the data under 
    #   rather than the model itself.  Pass a Proc that evaluates to the model containing the amee 
    #   profile - eg Proc.new{|model| model.method}, Proc.new{|model| model.parent.method}.  The 
    #   referenced model must store the amee profile key under the field amee_profile (as would be
    #   provided by the has_amee_profile decleration)
    # * nameless - if set then automatically assign the name field so the user doesn't have to
    #   (still requires the name field in the database as a name must be set to store in amee)
    # * has_date_range - will check for the presence of a start_date and end_date on the object
    #   and pass that through to AMEE to store with the data.  Requires the start_date and end_date
    #   database fields as described in header.
    # * repetitions - allows repetitions of the data at a database level where AMEE doesn't support
    #   it natively.  For example multiple journeys can be setup with this option.  The value stored
    #   in AMEE will be the total for all journeys.  Requires the repetitions database field as 
    #   described in header.
    def has_carbon_data_stored_in_amee(options = {})
      if options[:profile]
        unless options[:profile].is_a?(Proc)
          warn '[DEPRECIATION] AmeeRailsLayer will no longer automatically provide the profile association.  The relationship to the amee profile will also need to be defined as a Proc.'
          belongs_to options[:profile]
          options[:profile] = Proc.new{|model| model.send(options[:profile])}
        end
      else
        has_amee_profile
      end
      
      validates_numericality_of :amount
      validate_on_create :units_are_valid
      validates_presence_of :start_date, :end_date if options[:has_date_range]
      unless options[:nameless]
        validates_length_of :name, :maximum => 250
      end
      if options[:singular_types]
        warn '[DEPRECIATION] singular_types option is no longer supported.'
      end
      if options[:repetitions]
        validates_numericality_of :repetitions, :only_integer => true
      end
      
      before_create :add_to_amee
      before_update :update_amee
      after_destroy :delete_from_amee
      
      write_inheritable_attribute(:amee_profile_proc, options[:profile]) if options[:profile]
      write_inheritable_attribute(:repetitions, true) if options[:repetitions]
      write_inheritable_attribute(:nameless_entries, true) if options[:nameless]
      write_inheritable_attribute(:has_date_range, true) if options[:has_date_range]
      
      include AmeeCarbonStore::InstanceMethods
    end
    
    # This method updates all the carbon caches for instances of this model.  Be aware this may
    # take some time depending on the number of rows.
    def update_carbon_caches
      find(:all).each do |item|
        item.update_carbon_output_cache
      end.size
    end
  end

  module InstanceMethods
    # Updates the carbon cache for this instance
    def update_carbon_output_cache
      update_attributes(:carbon_output_cache => amee_profile_item.total_amount)
    end
    
    # Returns whether the passed date lies between this instances start and end date.  This is only
    # useful when using with date ranges - ie has_date_range is passed as option into
    # has_carbon_data_stored_in_amee
    def covers_date?(date)
      start_date <= date && end_date > date
    end

    protected
    # The AmeeCategory the model instance is associated with must be returned by this method.  The
    # version in this module raises an exception so this method must be overriden in the class
    # including this module.  See README for an examples of how to do this for models that are just
    # one type and models that can be many types.
    def amee_category
      raise "Must be implemented in model"
    end
    
    # Override this method to pass additional options to AMEE on creation of the AMEE profile item
    # for the model instance.  For example if you were creating an item in /home/waste/lifecycle 
    # and wanted to set disposalEmissionsOnly as true you could override this method in the model 
    # with {:disposalEmissionsOnly => true}
    def additional_options
      nil
    end
    
    # Override this method when the category type used in AmeeCategory does not result in the 
    # correct key to store the data against in the AMEE API (the key is looked up from category
    # type in AmeeCategory::CATEGORY_TYPES).  Normally this lookup would result in values such
    # as distancePerJourney, mass etc but in some cases it won't be directly inferable from the
    # category type you want.  If using this for multiple types in a model be sure to only
    # override when the model type is the correct one and not for all types.
    # 
    # For example if you were using /home/waste/lifecyclewaste with waste type "other waste" and
    # category_type :weight, you might want to specify a landfill amount rather than a mass.  This
    # could be achieved by overriding this method to return "quantityLandfill".
    def amount_symbol
      amee_category.category_type_from_amee_api_unit(get_units)
    end

    private
    def units_are_valid
      errors.add("units", "are not valid") if amount_symbol.nil?
    end

    def add_to_amee
      profile = create_amee_profile
      self.amee_profile_item_id = profile.uid
      self.carbon_output_cache = profile.total_amount
      return true
    end
    
    def update_amee
      repetitions_changed = self.class.read_inheritable_attribute(:repetitions) && repetitions_changed?
      if (name_changed? || units_changed? || amount_changed? || repetitions_changed)
        result = AMEE::Profile::Item.update(connection_to_amee, amee_profile_item_path, 
          :name => get_name, amount_symbol => get_amount, :get_item => true)
        self.carbon_output_cache = result.total_amount
      end
      return true
    end

    def delete_from_amee
      AMEE::Profile::Item.delete(connection_to_amee, amee_profile_item_path)
    rescue Exception => e
      logger.error "Unable to remove '#{amee_profile_item_path}' from AMEE"
    end

    def create_amee_profile
      options = {:name => get_name, amount_symbol => get_amount,
        amount_unit_symbol => get_units, :get_item => true, 
        :returnUnit => "kg", :returnPerUnit => "year"}
      if self.class.read_inheritable_attribute(:has_date_range)
        options.merge!(:start_date => self.start_date, :end_date => self.end_date)
      end
      options.merge!(additional_options) if additional_options
      AMEE::Profile::Item.create(amee_profile_category, amee_data_category_uid, options)
    end

    # TODO can be renamed to amee_connection once ruby-amee rails lib merged in
    def connection_to_amee
      profile_proc = self.class.read_inheritable_attribute(:amee_profile_proc)
      profile_proc ? profile_proc.call(self).amee_connection : amee_connection
    end
    
    def amee_profile_path
      profile_proc = self.class.read_inheritable_attribute(:amee_profile_proc)
      profile_proc ? "/profiles/#{profile_proc.call(self).amee_profile}" : "/profiles/#{amee_profile}"
    end

    def amee_profile_item
      @amee_profile_item_cache ||= AMEE::Profile::Item.get(connection_to_amee, 
        amee_profile_item_path)
    end

    def amee_profile_item_path
      "#{amee_profile_path}#{amee_category.path}/#{amee_profile_item_id}"
    end
    
    def amee_profile_category
      AMEE::Profile::Category.get(connection_to_amee, "#{amee_profile_path}#{amee_category.path}")
    end

    def amee_data_category_uid
      Rails.cache.fetch("#{DRILLDOWN_CACHE_PREFIX}_#{amee_category.drill_down_path.gsub(/[^\w]/, '')}") do
        AMEE::Data::DrillDown.get(connection_to_amee, amee_category.drill_down_path).choices.first
      end
    end

    def amount_unit_symbol
      (amount_symbol.to_s + "Unit").to_sym
    end
    
    def get_name
      self.class.read_inheritable_attribute(:nameless_entries) ? "#{self.class.name}_#{Time.now.to_i}" : self.name
    end
    
    def get_amount      
      if self.class.read_inheritable_attribute(:repetitions)
        result = self.amount * self.repetitions
      else
        result = self.amount
      end
      
      if amee_category.has_alternative_unit?(self.units)
        result * amee_category.alternative_unit_conversion_factor(self.units)
      else
        result
      end
    end
    
    def get_units
      if amee_category.has_alternative_unit?(self.units)
        amee_category.alternative_unit_converts_to(self.units).to_s
      else
        self.units
      end
    end
  end
end