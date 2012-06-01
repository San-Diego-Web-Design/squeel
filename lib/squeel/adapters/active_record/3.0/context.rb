require 'squeel/context'

module Squeel
  module Adapters
    module ActiveRecord
      class Context < ::Squeel::Context
        # Because the AR::Associations namespace is insane
        JoinBase = ::ActiveRecord::Associations::ClassMethods::JoinDependency::JoinBase

        def initialize(object)
          super
          @base = object.join_base
          @engine = @base.arel_engine
          @arel_visitor = Arel::Visitors.visitor_for @engine
          @default_table = Arel::Table.new(@base.table_name, :as => @base.aliased_table_name, :engine => @engine)
        end

        def find(object, parent = @base)
          if JoinBase === parent
            case object
            when String, Symbol, Nodes::Stub
              assoc_name = object.to_s
              @object.join_associations.detect { |j|
                j.reflection.name.to_s == assoc_name && j.parent == parent
              }
            when Nodes::Join
              @object.join_associations.detect { |j|
                j.reflection.name == object.name && j.parent == parent &&
                (object.polymorphic? ? j.reflection.klass == object._klass : true)
              }
            else
              @object.join_associations.detect { |j|
                j.reflection == object && j.parent == parent
              }
            end
          end
        end

        def traverse(keypath, parent = @base, include_endpoint = false)
          parent = @base if keypath.absolute?
          keypath.path_without_endpoint.each do |key|
            parent = find(key, parent) || key
          end
          parent = find(keypath.endpoint, parent) if include_endpoint

          parent
        end

        private

        def get_table(object)
          if [Symbol, String, Nodes::Stub].include?(object.class)
            Arel::Table.new(object.to_s, :engine => @engine)
          elsif Nodes::Join === object
            object._klass ? object._klass.arel_table : Arel::Table.new(object._name, :engine => @engine)
          elsif object.respond_to?(:aliased_table_name)
            Arel::Table.new(object.table_name, :as => object.aliased_table_name, :engine => @engine)
          else
            raise ArgumentError, "Unable to get table for #{object}"
          end
        end

        def classify(object)
          if Class === object
            object
          elsif object.respond_to? :active_record
            object.active_record
          else
            raise ArgumentError, "#{object} can't be converted to a class"
          end
        end

      end
    end
  end
end
