# frozen_string_literal: true

module I18nJS
  require "i18n-js/plugin"

  class ExportFilesPlugin < I18nJS::Plugin
    CONFIG_KEY = :export_files

    def self.setup
      I18nJS::Schema.root_keys << CONFIG_KEY
    end

    def self.validate_schema(config:)
      return unless config.key?(CONFIG_KEY)

      plugin_config = config[CONFIG_KEY]
      valid_keys = %i[enabled files]
      schema = I18nJS::Schema.new(config)

      schema.expect_required_keys(valid_keys, plugin_config)
      schema.reject_extraneous_keys(valid_keys, plugin_config)
      schema.expect_enabled_config(CONFIG_KEY, plugin_config[:enabled])
      schema.expect_array_with_items(:files, plugin_config[:files])

      plugin_config[:files].each do |exports|
        schema.expect_required_keys(%i[template output], exports)
        schema.reject_extraneous_keys(%i[template output], exports)
        schema.expect_type(:template, exports[:template], String, exports)
        schema.expect_type(:output, exports[:output], String, exports)
      end
    end

    def self.after_export(files:, config:)
      return unless config.dig(CONFIG_KEY, :enabled)

      exports = config.dig(CONFIG_KEY, :files)

      require "erb"
      require "digest/md5"
      require "json"

      files.each do |file|
        dir = File.dirname(file)
        name = File.basename(file)
        extension = File.extname(name)
        base_name = File.basename(file, extension)

        exports.each do |export|
          translations = JSON.load_file(file)
          template = Template.new(
            file: file,
            translations: translations,
            template: export[:template]
          )

          contents = template.render

          output = format(
            export[:output],
            dir: dir,
            name: name,
            extension: extension,
            digest: Digest::MD5.hexdigest(contents),
            base_name: base_name
          )

          File.open(output, "w") do |io|
            io << contents
          end
        end
      end
    end

    class Template
      attr_accessor :file, :translations, :template

      def initialize(**kwargs)
        kwargs.each do |key, value|
          public_send("#{key}=", value)
        end
      end

      def banner(comment: "// ", include_time: true)
        [
          "#{comment}File generated by i18n-js",
          include_time ? " on #{Time.now}" : nil
        ].compact.join
      end

      def render
        ERB.new(File.read(template)).result(binding)
      end
    end
  end

  I18nJS.register_plugin(ExportFilesPlugin)
end
