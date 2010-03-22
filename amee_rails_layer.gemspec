# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{amee_rails_layer}
  s.version = "0.1.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["George Palmer"]
  s.date = %q{2010-03-22}
  s.description = %q{We need a longer description of your gem}
  s.email = %q{george.palmer@gmail.com}
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    ".document",
     ".gitignore",
     "LICENSE",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "amee_rails_layer.gemspec",
     "lib/amee_rails_layer.rb",
     "lib/amee_rails_layer/amee_carbon_store.rb",
     "lib/amee_rails_layer/amee_category.rb",
     "lib/amee_rails_layer/unit.rb",
     "rails/init.rb",
     "test/helper.rb",
     "test/test_amee-abstraction-layer-gem.rb"
  ]
  s.homepage = %q{http://github.com/georgepalmer/amee-abstraction-layer-gem}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{An abstraction layer for building applications around the AMEE API}
  s.test_files = [
    "test/helper.rb",
     "test/test_amee-abstraction-layer-gem.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<thoughtbot-shoulda>, [">= 0"])
    else
      s.add_dependency(%q<thoughtbot-shoulda>, [">= 0"])
    end
  else
    s.add_dependency(%q<thoughtbot-shoulda>, [">= 0"])
  end
end

