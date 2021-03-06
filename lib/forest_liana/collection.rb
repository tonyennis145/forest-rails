module ForestLiana::Collection
  extend ActiveSupport::Concern

  module ClassMethods
    attr_accessor :active_record_class
    attr_accessor :collection_name
    attr_accessor :is_read_only
    attr_accessor :is_searchable

    def collection(collection_name, opts = {})
      self.collection_name = collection_name.to_s
      self.is_read_only = opts[:read_only] || false
      self.is_searchable = opts[:is_searchable] || true
    end

    def action(name, opts = {})
      opts[:id] = "#{self.collection_name.to_s}.#{name}"
      opts[:name] = name
      model.actions << ForestLiana::Model::Action.new(opts)
    end

    def segment(name, opts = {}, &block)
      opts[:id] = "#{self.collection_name.to_s}.#{name}"
      opts[:name] = name
      model.segments << ForestLiana::Model::Segment.new(opts, &block)
    end

    def field(name, opts, &block)
      opts[:read_only] = true unless opts.has_key?(:read_only)
      opts[:is_searchable] = false unless opts.has_key?(:is_searchable)

      opts[:read_only] = false if opts.has_key?(:set)
      opts[:is_searchable] = true if opts.has_key?(:search)

      model.fields << opts.merge({
        field: name,
        :'is-read-only' => opts[:read_only],
        :'is-searchable' => opts['is_searchable'],
        :'is-virtual' => true
      })

      if serializer_name && ForestLiana::UserSpace.const_defined?(
          serializer_name)
        ForestLiana::UserSpace.const_get(serializer_name).class_eval do
          attribute(name, &block)
        end
      end
    end

    def has_many(name, opts, &block)
      model.fields << opts.merge({
        field: name,
        :'is-searchable' => false,
        type: ['String']
      })

      if serializer_name && ForestLiana::UserSpace.const_defined?(
          serializer_name)
        ForestLiana::UserSpace.const_get(serializer_name).class_eval do
          has_many(name, name: name)
        end
      end
    end

    def belongs_to(name, opts, &block)
      model.fields << opts.merge({
        field: name,
        :'is-searchable' => false,
        type: 'String'
      })

      if serializer_name && ForestLiana::UserSpace.const_defined?(
          serializer_name)
        ForestLiana::UserSpace.const_get(serializer_name).class_eval do
          has_one(name, name: name, include_data: true, &block)
        end
      end
    end

    private

    def model
      collection = ForestLiana.apimap.find do |x|
        x.name.to_s == self.collection_name.try(:to_s)
      end

      if collection.blank?
        collection = ForestLiana::Model::Collection.new({
          name: self.collection_name.to_s,
          is_read_only: self.is_read_only,
          is_searchable: self.is_searchable,
          is_virtual: true,
          fields: []
        })

        ForestLiana.apimap << collection
      end

      collection
    end

    def active_record_class
      ForestLiana::SchemaUtils.find_model_from_collection_name(
        self.collection_name)
    end

    def serializer_name
      return if active_record_class.blank?
      class_name = active_record_class.table_name.classify
      module_name = class_name.deconstantize

      name = module_name if module_name
      name += class_name.demodulize

      "ForestLiana::UserSpace::#{name}Serializer"
    end

    def serializer_name_for_reference(reference)
      association = opts[:reference].split('.').first
      class_name = association.classify
      module_name = class_name.deconstantize

      name = module_name if module_name
      name += class_name.demodulize

      "ForestLiana::UserSpace::#{name}Serializer"
    end
  end
end
