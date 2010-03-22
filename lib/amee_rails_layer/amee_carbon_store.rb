# AmeeCategory:
# TODO check logic for unit conversion is correct.  Look at extra methods in models in overbury, would 
#      changes made break any of that?  Put into OS branch and test
# TODO check @unit_type bit works after renamed from type and also associated private method changes
# TODO check works with item_value_names and has_alternative_units? as private methods
# Remove include AmeeCarbonStore and in models add @@per_page and cattr_reader :per_page [opensource branch, done nesta one]

module AmeeCarbonStore
  def self.included(base)
    base.extend ClassMethods
    
    base.module_eval do
      belongs_to :project
    end
  end

  module ClassMethods
    def has_carbon_data_stored_in_amee(options = {})
      validates_numericality_of :amount
      validate_on_create :units_are_valid
      unless options[:nameless]
        if options[:has_date_range]
          validates_presence_of :start_date, :end_date
          validate :name_is_unique_given_date_range
        else
          validates_uniqueness_of :name, :scope => :project_id
        end
        validates_format_of :name, :with => /\A[\w -]+\Z/, :message => "must be letters, numbers, spaces or underscores only"
        validates_length_of :name, :maximum => 250
      end
      if options[:singular_types]
        validate_on_create :maximum_one_instance_for_each_type
      end
      if options[:type_amount_repeats]
        validates_numericality_of :repetitions, :only_integer => true
      end
      
      before_create :add_to_amee
      before_update :update_amee
      after_destroy :delete_from_amee
      
      write_inheritable_attribute(:type_amount_repeats, true) if options[:type_amount_repeats]
      write_inheritable_attribute(:nameless_entries, true) if options[:nameless]
      write_inheritable_attribute(:has_date_range, true) if options[:has_date_range]
      
      include AmeeCarbonStore::InstanceMethods
    end
    
    def update_carbon_caches
      find(:all).each do |item|
        item.update_carbon_output_cache
      end.size
    end
  end

  module InstanceMethods
    def update_carbon_output_cache
      update_attributes(:carbon_output_cache => amee_profile_item.total_amount)
    end
    
    # Only useful if model has date range option
    def covers_date?(date)
      start_date <= date && end_date > date
    end

    protected
    # Should return an AmeeCategory the model instance is associated with
    def amee_category
      raise "Must be implemented in model"
    end
    
    # Override in model to pass additional options on create
    def additional_options
      nil
    end
    
    # Override this if the amount symbol isn't inferable from the units
    def amount_symbol
      amee_category.category_type_from_amee_api_unit(get_units)
    end

    def amount_unit_symbol
      (amount_symbol.to_s + "Unit").to_sym
    end

    private    
    def units_are_valid
      errors.add("units", "are not valid") if amount_symbol.nil?
    end
    
    def name_is_unique_given_date_range
      self.class.find_all_by_name(self.name).each do |record|
        next if record.id == self.id
        unless (self.start_date < record.start_date && self.end_date <= record.start_date) ||
               (self.start_date >= record.end_date && self.end_date > record.end_date)
          errors.add_to_base("Entry already added covering dates within that range")
          return false
        end
      end
    end

    # We call the distance/weight/... of an item the amount.  AMEE calls this value.  It refers
    # to total_amount for the amount of carbon so don't confuse these.
    def amee_profile_item
      @amee_profile_item_cache ||= AMEE::Profile::Item.get(project.amee_connection, 
        amee_profile_item_path)
    end

    def amee_profile_item_path
      "#{project.profile_path}#{amee_category.path}/#{amee_profile_item_id}"
    end
    
    def amee_profile_category
      AMEE::Profile::Category.get(project.amee_connection, "#{project.profile_path}#{amee_category.path}")
    end

    def add_to_amee
      profile = create_amee_profile
      self.amee_profile_item_id = profile.uid
      self.carbon_output_cache = profile.total_amount
      return true
    end

    def create_amee_profile
      options = {:name => get_name, amount_symbol => get_amount,
        amount_unit_symbol => get_units, :get_item => true}
      if self.class.read_inheritable_attribute(:has_date_range)
        options.merge!(:start_date => self.start_date, :end_date => self.end_date)
      end
      options.merge!(additional_options) if additional_options
      AMEE::Profile::Item.create(amee_profile_category, amee_data_category_uid, options)
    end

    def amee_data_category_uid
      Rails.cache.fetch("#{DRILLDOWN_CACHE_PREFIX}_#{amee_category.drill_down_path.gsub(/[^\w]/, '')}") do
        AMEE::Data::DrillDown.get(project.amee_connection, amee_category.drill_down_path).choices.first
      end
    end

    def update_amee
      result = AMEE::Profile::Item.update(project.amee_connection, amee_profile_item_path, 
        :name => get_name, amount_symbol => get_amount, :get_item => true)
      self.carbon_output_cache = result.total_amount
      return true
    end

    def maximum_one_instance_for_each_type
      model_type = "#{self.class.name.underscore}_type".to_sym
      if self.class.send(:find, :first, :conditions => {:project_id => project.id, model_type => send(model_type)})
        errors.add_to_base "This project already has a #{amee_category.name} entry"
      end
    end

    def delete_from_amee
      AMEE::Profile::Item.delete(project.amee_connection, amee_profile_item_path)
    rescue Exception => e
      logger.error "Unable to remove '#{amee_profile_item_path}' from AMEE"
    end
    
    def get_name
      self.class.read_inheritable_attribute(:nameless_entries) ? "#{self.class.name}_#{Time.now.to_i}" : self.name
    end
    
    def get_amount
      # TODO what if both??
      if amee_category.has_alternative_unit?(self.units)
        self.amount * amee_category.alternative_unit_conversion_factor(self.units)
      elsif self.class.read_inheritable_attribute(:type_amount_repeats)
        self.amount * self.repetitions
      else
        self.amount
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