module BEL::RdfRepository::Plugins

  module Mongo

    extend ::BEL::RdfRepository::ClassMethods

    NAME        = 'Mongo RDF Repository'
    DESCRIPTION = 'A repository of RDF data on MongoDB.'

    def self.create_repository(options = {})
      require 'rdf'
      require 'rdf/mongo'

      RDF::Mongo::Repository.new(options)
    end

    def self.name
      NAME
    end

    def self.description
      DESCRIPTION
    end
  end
end
