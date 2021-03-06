require 'forwardable'
module ActiveReporting
  class ReportingDimension
    extend Forwardable
    def_delegators :@dimension, :name, :type, :klass, :association, :model, :hierarchical?

    def self.build_from_dimensions(fact_model, dimensions)
      Array(dimensions).map do |dim|
        dimension_name, label = dim.is_a?(Hash) ? Array(dim).flatten : [dim, nil]
        found_dimension = fact_model.dimensions[dimension_name.to_sym]
        if found_dimension.nil?
          raise UnknownDimension, "Dimension '#{dim}' not found on fact model '#{fact_model}'"
        end
        new(found_dimension, label: label)
      end
    end

    def initialize(dimension, label: nil)
      @dimension = dimension
      determine_label(label)
    end

    # The foreign key to use in queries
    #
    # @return [String]
    def foreign_key
      association ? association.foreign_key : name
    end

    # Fragments of a select statement for queries that use the dimension
    #
    # @return [Array]
    def select_statement(with_identifier: true)
      return [degenerate_fragment] if type == :degenerate

      ss = ["#{label_fragment} AS #{name}"]
      ss << "#{identifier_fragment} AS #{name}_identifier" if with_identifier
      ss
    end

    # Fragments of a group by clause for queries that use the dimension
    #
    # @return [Array]
    def group_by_statement(with_identifier: true)
      return [degenerate_fragment] if type == :degenerate

      group = [label_fragment]
      group << identifier_fragment if with_identifier
      group
    end

    # Fragment of an order by clause for queries that sort by the dimension
    #
    # @return [String]
    def order_by_statement(direction:)
      direction = direction.to_s.upcase
      raise "Ording direction should be 'asc' or 'desc'" unless %w(ASC DESC).include?(direction)
      return "#{degenerate_fragment} #{direction}" if type == :degenerate
      "#{label_fragment} #{direction}"
    end

    # Looks up the dimension label callback for the label
    #
    # @return [Lambda, NilClass]
    def label_callback
      klass.fact_model.dimension_label_callbacks[@label]
    end

    private ####################################################################

    def determine_label(label)
      @label = label.to_sym if label.present? && validate_hierarchical_label(label)
      @label ||= dimension_fact_model.dimension_label || Configuration.default_dimension_label
    end

    def validate_hierarchical_label(hierarchical_label)
      if !hierarchical?
        raise InvalidDimensionLabel, "#{name} must be hierarchical to use label #{hierarchical_label}"
      end
      unless dimension_fact_model.hierarchical_levels.include?(hierarchical_label.to_sym)
        raise InvalidDimensionLabel, "#{hierarchical_label} is not a hierarchical label in #{name}"
      end
      true
    end

    def degenerate_fragment
      "#{model.quoted_table_name}.#{name}"
    end

    def identifier_fragment
      "#{klass.quoted_table_name}.#{klass.primary_key}"
    end

    def label_fragment
      "#{klass.quoted_table_name}.#{@label}"
    end

    def dimension_fact_model
      @dimension_fact_model ||= klass.fact_model
    end
  end
end
