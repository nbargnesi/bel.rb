module BEL::Extension::Format

  class FormatJGF

    include Formatter

    ID          = :jgf
    MEDIA_TYPES = %i(application/vnd.jgf+json)
    EXTENSIONS  = %i(jgf.json)

    def initialize
      json_module = load_implementation_module!
      @json_reader = json_module::JSONReader
      @json_writer = json_module::JSONWriter
    end
    
    def id
      ID
    end

    def media_types
      MEDIA_TYPES
    end

    def file_extensions
      EXTENSIONS
    end

    def deserialize(data, &block)
      @json_reader.new(data).each.lazy.select { |obj|
        obj.include?(:nodes) && obj.include?(:edges)
      }.flat_map { |graph|
        unwrap(graph)
      }
    end

    def serialize(objects, writer = StringIO.new, options = {})
      graph = {
        :type  => 'BEL-V1.0',
        :nodes => [],
        :edges => []
      }

      objects.each do |evidence|
        stmt    = evidence.bel_statement
        subject = stmt.subject.to_bel

        graph[:nodes] << {
          :id    => subject,
          :label => subject
        }

        if stmt.object
          object  = stmt.object.to_bel
          graph[:nodes] << {
            :id    => object,
            :label => object
          }
          graph[:edges] << {
            :source   => subject,
            :relation => stmt.relationship,
            :target   => object
          }
        end
      end
      graph[:nodes].uniq!

      json_writer = @json_writer.new
      writer     << json_writer.write_json_object(
        {
          :graph => graph
        }
      )
      writer
    end

    private

    def unwrap(graph)
      # index nodes
      id_nodes = Hash[
        graph[:nodes].map { |node|
          [node[:id], (node[:label] || node[:id])]
        }
      ]
      ids = id_nodes.keys.to_set

      # map edges to statements
      bel_statements = graph[:edges].map { |edge|
        src, rel, tgt = edge.values_at(:source, :relation, :target)
        source_node = id_nodes[src]
        target_node = id_nodes[tgt]

        if !source_node || !target_node
          nil
        else
          ids.delete(source_node)
          ids.delete(target_node)

          # semantic default
          rel  = 'association' unless rel

          bel_statement = ::BEL::Script.parse(
            "#{source_node} #{rel} #{target_node}\n"
          ).select { |obj|
            obj.is_a? ::BEL::Model::Statement
          }.first
        end
      }.compact

      # map island nodes to bel statements
      if !ids.empty?
        bel_statements.concat(
          ids.map { |id|
            ::BEL::Script.parse(
              "#{id_nodes[id]}\n"
            ).select { |obj|
              obj.is_a? ::BEL::Model::Statement
            }.first
          }
        )
      end

      # map statements to evidence objects
      bel_statements.map { |bel_statement|
        ::BEL::Model::Evidence.create(:bel_statement => bel_statement)
      }
    end

    # Load the most suitable JSON implementation available within ruby.
    # The load order attempted is:
    # - oj              (provides stream parsing utilizing event callbacks)
    # - TODO jrjackson  (stream parsing support for JRuby)
    # - multi_json      (simple buffering abstraction over multiple ruby libraries)
    # - json            (stock ruby implementation)
    def load_implementation_module!
      impl_modules  = [
        'json/oj',
        'json/jrjackson',
        'json/multi_json',
        'json/ruby_json'
      ]

      load_success = impl_modules.any? { |impl_module|
        begin
          require_relative impl_module
          true
        rescue LoadError
          # Could not load +impl_module+; try the next one
          false
        end
      }

      if load_success
        BEL::Extension::Format::JSONImplementation
      else
        mod_s = impl_modules.join(', ')
        msg   = "Could not load any JSON implementation (tried: #{mod_s})."
        raise LoadError.new(msg)
      end
    end
  end

  register_formatter(FormatJGF.new)
end
