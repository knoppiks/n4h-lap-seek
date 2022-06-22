module Seek
  class IndexTableColumnDefinitions
    def self.allowed_columns(resource)
      columns = required_columns(resource) | default_columns(resource)
      columns |= definition_for(resource, :additional_allowed) | definitions[:general][:additional_allowed]
      columns -= definition_for(resource, :blocked)
      check(columns, resource).uniq
    end

    def self.required_columns(resource)
      columns = definition_for(resource, :required) | definitions[:general][:required]
      columns -= definition_for(resource, :blocked)
      check(columns, resource).uniq
    end

    def self.default_columns(resource)
      columns = definition_for(resource, :default) | definitions[:general][:default]
      columns -= definition_for(resource, :blocked)
      check(columns, resource).uniq
    end

    def self.definition_for(resource, category)
      return [] unless definitions[resource.model_name.name.underscore]

      definitions[resource.model_name.name.underscore][category] || []
    end

    def self.definitions
      @definitions ||= load_yaml
    end

    def self.load_yaml
      yaml = YAML.load_file(File.join(File.dirname(File.expand_path(__FILE__)), 'index_table_columns.yml'))
      HashWithIndifferentAccess.new(yaml)[:columns]
    end

    def self.check(cols, resource)
      cols.select do |col|
        resource.respond_to?(col)
      end
    end
  end
end
