# frozen-string-literal: true

module Mobility
  module Plugins
=begin

Defines +method_missing+ and +respond_to_missing?+ methods for a set of
attributes such that a method call using a locale accessor, like:

  article.title_pt_br

will return the value of +article.title+ with the locale set to +pt-BR+ around
the method call. The class is called "FallthroughAccessors" because when
included in a model class, locale-specific methods will be available even if
not explicitly defined with the +locale_accessors+ option.

This is a less efficient (but more open-ended) implementation of locale
accessors, for use in cases where the locales to be used are not known when the
model class is generated.

=end
    module FallthroughAccessors
      extend Plugin

      default true

      # Apply fallthrough accessors plugin to attributes.
      # @param [Translations] translations
      # @param [Boolean] option
      initialize_hook do
        if options[:fallthrough_accessors]
          define_fallthrough_accessors(names)
        end
      end

      private

      def define_fallthrough_accessors(*names)
        method_name_regex = /\A(?<method_base>(?<attribute>#{names.join('|')})_(?<locale>[a-z]{2})(_(?<suffix>[a-z]{2}))?)(?<operator>=|\?)?\z/.freeze

        klass = self

        define_method :method_missing do |method_name, *args, &block|
          if matches = method_name.match(method_name_regex)
            attribute = matches[:attribute]
            method_base = matches[:method_base]

            locale = matches[:locale]
            locale = "#{locale}-#{matches[:suffix].upcase}" if matches[:suffix]

            klass.define_method method_base do |*args, **options|
              public_send(attribute, *args, **options, locale: locale)
            end

            klass.define_method "#{method_base}?" do |*args, **options|
              public_send("#{attribute}?", *args, **options, locale: locale)
            end

            klass.define_method "#{method_base}=" do |*args, **options|
              public_send("#{attribute}=", *args, **options, locale: locale)
            end

            public_send(method_name, *args, &block)
          else
            super(method_name, *args, &block)
          end
        end

        # Following is needed in order to not swallow `kwargs` on ruby >= 3.0.
        # Otherwise `kwargs` are not passed by `super` to a possible other
        # `method_missing` defined like this:
        #
        # def method_missing(name, *args, **kwargs, &block); end
        ruby2_keywords :method_missing

        define_method :respond_to_missing? do |method_name, include_private = false|
          (method_name =~ method_name_regex) || super(method_name, include_private)
        end
      end
    end

    register_plugin :fallthrough_accessors, FallthroughAccessors
  end
end
