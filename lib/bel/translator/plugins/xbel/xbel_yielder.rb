require 'bel'
require 'rexml/document'

module BEL::Translator::Plugins
  module Xbel
    class XBELYielder
      FUNCTIONS = ::BEL::Language::FUNCTIONS

      def initialize(data, options = {})
        @data                     = data
        @streaming                = options.fetch(:streaming, false)
        @annotation_reference_map = options.fetch(:annotation_reference_map, nil)
        @namespace_reference_map  = options.fetch(:namespace_reference_map, nil)
        # default BEL version to 2 for default behavior
        @bel_version = 2
      end

      def each
        if block_given?
          combiner =
            if @streaming
              BEL::Nanopub::StreamingNanopubCombiner.new(@data)
            elsif @annotation_reference_map && @namespace_reference_map
              BEL::Nanopub::MapReferencesCombiner.new(
                @data,
                BEL::Nanopub::HashMapReferences.new(
                  @annotation_reference_map,
                  @namespace_reference_map
                )
              )
            else
              BEL::Nanopub::BufferingNanopubCombiner.new(@data)
            end

          header_flag = true

          # yield <document>
          el_document = XBELYielder.document
          yield start_element_string(el_document)

          el_statement_group = nil
          nanopub_count = 0
          combiner.each { |nanopub|
            # is BEL version 1.0?
            if nanopub.metadata.bel_version == '1.0'
              @bel_version = 1
            end
            if header_flag
              # document header
              el_statement_group = XBELYielder.statement_group

              yield element_string(
                XBELYielder.header(nanopub.metadata.document_header)
              )
              yield element_string(
                XBELYielder.namespace_definitions(combiner.namespace_references)
              )
              yield element_string(
                XBELYielder.annotation_definitions(combiner.annotation_references)
              )

              yield start_element_string(el_statement_group)

              header_flag = false
            end

            yield element_string(XBELYielder.nanopub(nanopub))
            nanopub_count += 1
          }

          if nanopub_count > 0
            yield end_element_string(el_statement_group)
          else
            # empty head sections; required for XBEL schema

            empty_header = Hash[%w(name description version).map { |element|
              [element, ""]
            }]
            yield element_string(XBELYielder.header(empty_header))
            yield element_string(XBELYielder.namespace_definitions([]))
            yield element_string(XBELYielder.annotation_definitions([]))
            yield element_string(XBELYielder.statement_group)
          end
          yield end_element_string(el_document)
        else
          to_enum(:each)
        end
      end

      def self.nanopub(nanopub)
        statement    = nanopub.bel_statement
        el_statement = REXML::Element.new('bel:statement')

        el_statement.add_element(self.annotation_group(nanopub))
        self.statement(statement, el_statement)

        el_statement
      end

      def self.statement(statement, el_statement)
        if statement.relationship
          el_statement.add_attribute 'bel:relationship', statement.relationship.to_s(:long)
        end

        if statement.subject
          el_subject = self.subject(statement.subject)
          el_statement.add_element(el_subject)
        end

        if statement.object
          el_object = self.object(statement.object)
          el_statement.add_element(el_object)
        end

        el_statement
      end

      def self.subject(subject)
        el_subject = REXML::Element.new('bel:subject')
        el_subject.add_element(self.term(subject))

        el_subject
      end

      def self.object(object)
        el_object = REXML::Element.new('bel:object')

        case object
        when ::BELParser::Expression::Model::Term
          el_object.add_element(self.term(object))
        when ::BELParser::Expression::Model::Statement
          el_statement = REXML::Element.new('bel:statement')
          el_object.add_element(el_statement)
          self.statement(object, el_statement)
        end
        el_object
      end

      def self.term(term)
        el_term   = REXML::Element.new('bel:term')
        el_term.add_attribute 'bel:function', term.function.to_s(:long)

        term.arguments.each do |arg|
          case arg
          when ::BELParser::Expression::Model::Term
            el_term.add_element(self.term(arg))
          when ::BELParser::Expression::Model::Parameter
            el_term.add_element(self.parameter(arg))
          end
        end
        el_term
      end

      def self.parameter(parameter)
        el_parameter      = REXML::Element.new('bel:parameter')
        el_parameter.text = parameter.value
        keyword           = parameter.namespace && parameter.namespace.keyword
        el_parameter.add_attribute 'bel:ns', keyword
        el_parameter
      end

      def self.annotation_group(nanopub)
        el_ag = REXML::Element.new('bel:annotationGroup')

        # XBEL citation
        if nanopub.citation && nanopub.citation.valid?
          el_ag.add_element(self.citation(nanopub.citation))
        end

        # XBEL nanopub (::BEL::Nanopub::Support)
        if nanopub.support && nanopub.support.value
          if @bel_version == 1
            xbel_evidence = REXML::Element.new('bel:evidence')
            xbel_evidence.text = nanopub.support.value
            el_ag.add_element(xbel_evidence)
          else
            xbel_support = REXML::Element.new('bel:support')
            xbel_support.text = nanopub.support.value
            el_ag.add_element(xbel_support)
          end
        end

        nanopub.experiment_context.each do |annotation|
          name, value = annotation.values_at(:name, :value)

          if value.respond_to?(:each)
            value.each do |v|
              el_anno      = REXML::Element.new('bel:annotation')
              el_anno.text = v
              el_anno.add_attribute 'bel:refID', name.to_s

              el_ag.add_element(el_anno)
            end
          else
              el_anno      = REXML::Element.new('bel:annotation')
              el_anno.text = value
              el_anno.add_attribute 'bel:refID', name.to_s

              el_ag.add_element(el_anno)
          end
        end

        metadata_keys = nanopub.metadata.keys - [:document_header, :bel_version]
        metadata_keys.each do |k|
          v = nanopub.metadata[k]
          if v.respond_to?(:each)
            v.each do |value|
              el_anno      = REXML::Element.new('bel:annotation')
              el_anno.text = value
              el_anno.add_attribute 'bel:refID', k.to_s

              el_ag.add_element(el_anno)
            end
          else
            el_anno      = REXML::Element.new('bel:annotation')
            el_anno.text = v
            el_anno.add_attribute 'bel:refID', k.to_s

            el_ag.add_element(el_anno)
          end
        end

        el_ag
      end

      def self.citation(citation)
        el_citation  = REXML::Element.new('bel:citation')

        if citation.type && !citation.type.to_s.empty?
          el_citation.add_attribute 'bel:type', citation.type
        end

        if citation.id && !citation.id.to_s.empty?
          el_reference      = REXML::Element.new('bel:reference')
          el_reference.text = citation.id
          el_citation.add_element(el_reference)
        end

        if citation.name && !citation.name.to_s.empty?
          el_name         = REXML::Element.new('bel:name')
          el_name.text    = citation.name
          el_citation.add_element(el_name)
        end

        if citation.date && !citation.date.to_s.empty?
          el_date         = REXML::Element.new('bel:date')
          el_date.text    = citation.date
          el_citation.add_element(el_date)
        end

        if citation.comment && !citation.comment.to_s.empty?
          el_comment      = REXML::Element.new('bel:comment')
          el_comment.text = citation.comment
          el_citation.add_element(el_comment)
        end

        if citation.authors && !citation.authors.to_s.empty?
          el_author_group = REXML::Element.new('bel:authorGroup')
          citation.authors.each do |author|
            el_author      = REXML::Element.new('bel:author')
            el_author.text = author
            el_author_group.add_element(el_author)
          end
          el_citation.add_element(el_author_group)
        end

        el_citation
      end

      def self.document
        el = REXML::Element.new('bel:document')

        if @bel_version == 1
          el.add_namespace('bel', 'http://belframework.org/schema/1.0/xbel')
          el.add_namespace('xsi', 'http://www.w3.org/2001/XMLSchema-instance')
          el.add_attribute('xsi:schemaLocation', 'http://belframework.org/schema/1.0/xbel http://resource.belframework.org/belframework/1.0/schema/xbel.xsd')
        else
          el.add_namespace('bel', 'http://resources.openbel.org/v2.0/lang/xml-schema/version_2.0/xbel')
          el.add_namespace('xsi', 'http://www.w3.org/2001/XMLSchema-instance')
          el.add_attribute('xsi:schemaLocation', 'http://resources.openbel.org/v2.0/lang/xml-schema/version_2.0/xbel')
        end

        el
      end

      def self.statement_group(declare_namespaces = false)
        el = REXML::Element.new('bel:statementGroup')

        if declare_namespaces
          if @bel_version == 1
            el.add_namespace('bel', 'http://belframework.org/schema/1.0/xbel')
            el.add_namespace('xsi', 'http://www.w3.org/2001/XMLSchema-instance')
            el.add_attribute('xsi:schemaLocation', 'http://belframework.org/schema/1.0/xbel http://resource.belframework.org/belframework/1.0/schema/xbel.xsd')
          else
            el.add_namespace('bel', 'http://resources.openbel.org/v2.0/lang/xml-schema/version_2.0/xbel')
            el.add_namespace('xsi', 'http://www.w3.org/2001/XMLSchema-instance')
            el.add_attribute('xsi:schemaLocation', 'http://resources.openbel.org/v2.0/lang/xml-schema/version_2.0/xbel')
          end
        end

        el
      end

      def self.header(hash)
        el_header = REXML::Element.new('bel:header')

        # normalize hash keys
        hash = Hash[
          hash.map { |k, v|
            k = k.to_s.dup
            k.downcase!
            k.gsub!(/[-_ .]/, '')
            [k, v]
          }
        ]

        (%w(name description version copyright) & hash.keys).each do |field|
          el      = REXML::Element.new("bel:#{field}")
          el.text = hash[field]
          el_header.add_element(el)
        end

        # add contactinfo with different element name (contactInfo)
        if hash.has_key?('contactinfo')
          el      = REXML::Element.new('bel:contactInfo')
          el.text = hash['contactinfo']
          el_header.add_element(el)
        end

        # add bel_version with different element name (belVersion)
        if hash.has_key?('belversion')
          el = REXML::Element.new('bel:belVersion')
          el.text = hash['belversion']
          el_header.add_element(el)
        else
          # apply defaults
          el = REXML::Element.new('bel:belVersion')
          el.text = '2.0'
          el_header.add_element(el)
        end

        # handle grouping for authors and licenses
        if hash.has_key?('authors')
          authors  = hash['authors']
          el_group = REXML::Element.new('bel:authorGroup')

          [authors].flatten.each do |author|
            el      = REXML::Element.new('bel:author')
            el.text = author.to_s
            el_group.add_element(el)
          end
          el_header.add_element(el_group)
        end
        if hash.has_key?('licenses')
          licenses = hash['licenses']
          el_group = REXML::Element.new('bel:licenseGroup')

          [licenses].flatten.each do |license|
            el      = REXML::Element.new('bel:license')
            el.text = license.to_s
            el_group.add_element(el)
          end
          el_header.add_element(el_group)
        end

        el_header
      end

      def self.namespace_definitions(list)
        el_nd = REXML::Element.new('bel:namespaceGroup')
        list.each do |namespace|
          if namespace.url?
            el = REXML::Element.new('bel:namespace')
            el.add_attribute 'bel:prefix', namespace.keyword
            if @bel_version == 1
              el.add_attribute 'bel:resourceLocation', namespace.uri
            else
              url_el = REXML::Element.new('bel:url')
              url_el.text = namespace.uri
              rsrc_el = REXML::Element.new('bel:resource')
              rsrc_el << url_el
              el << rsrc_el
            end
            el_nd.add_element(el)
          elsif namespace.uri?
            el = REXML::Element.new('bel:namespace')
            el.add_attribute 'bel:prefix', namespace.keyword
            if @bel_version == 1
              el.add_attribute 'bel:resourceLocation', namespace.uri
            else
              uri_el = REXML::Element.new('bel:uri')
              uri_el.text = namespace.uri
              rsrc_el = REXML::Element.new('bel:resource')
              rsrc_el << uri_el
              el << rsrc_el
            end
            el_nd.add_element(el)
          end
        end

        el_nd
      end

      def self.annotation_definitions(list)
        el_ad = REXML::Element.new('bel:annotationDefinitionGroup')
        internal = []
        external = []
        list.each do |annotation|
          case annotation.type.to_sym
          when :url
            el = REXML::Element.new('bel:externalAnnotationDefinition')
            el.add_attribute 'bel:id',  annotation.keyword
            external << el
            if @bel_version == 1
              el.add_attribute 'bel:url', annotation.domain
            else
              url_el = REXML::Element.new('bel:url')
              url_el.text = annotation.domain
              rsrc_el = REXML::Element.new('bel:resource')
              rsrc_el << url_el
              el << rsrc_el
            end
          when :uri
            el = REXML::Element.new('bel:externalAnnotationDefinition')
            el.add_attribute 'bel:id',  annotation.keyword
            external << el
            if @bel_version == 1
              el.add_attribute 'bel:url', annotation.domain
            else
              uri_el = REXML::Element.new('bel:uri')
              uri_el.text = annotation.domain
              rsrc_el = REXML::Element.new('bel:resource')
              rsrc_el << uri_el
              el << rsrc_el
            end
          when :pattern
            el = REXML::Element.new('bel:internalAnnotationDefinition')
            el.add_attribute 'bel:id', annotation.keyword
            el.add_element(REXML::Element.new('bel:description'))
            el.add_element(REXML::Element.new('bel:usage'))

            el_pattern      = REXML::Element.new('bel:patternAnnotation')
            el_pattern.text =
              annotation.domain.respond_to?(:source) ?
                annotation.domain.source : annotation.domain

            el.add_element(el_pattern)
            internal << el
          when :list
            el = REXML::Element.new('bel:internalAnnotationDefinition')
            el.add_attribute 'bel:id', annotation.keyword
            el.add_element(REXML::Element.new('bel:description'))
            el.add_element(REXML::Element.new('bel:usage'))

            el_list = REXML::Element.new('bel:listAnnotation')
            if annotation.domain.respond_to?(:each)
              annotation.domain.each do |value|
                el_list_value      = REXML::Element.new('bel:listValue')
                el_list_value.text = value
                el_list.add_element(el_list_value)
              end
            else
              el_list_value      = REXML::Element.new('bel:listValue')
              el_list_value.text = annotation.domain
              el_list.add_element(el_list_value)
            end

            el.add_element(el_list)
            internal << el
          else
            el = nil
          end
        end

        # first add internal annotation definitions
        internal.each do |internal_element|
          el_ad.add_element(internal_element)
        end

        # second add external annotation definitions
        external.each do |external_element|
          el_ad.add_element(external_element)
        end

        el_ad
      end

      def start_element_string(element)
        element.to_s.gsub(%r{(/>)}, '>')
      end
      private :start_element_string

      def end_element_string(element)
        "</#{element.expanded_name}>"
      end
      private :end_element_string

      def element_string(element)
        element.to_s
      end
      private :element_string
    end
  end
end
