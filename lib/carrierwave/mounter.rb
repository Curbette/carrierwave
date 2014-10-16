module CarrierWave

  # this is an internal class, used by CarrierWave::Mount so that
  # we don't pollute the model with a lot of methods.
  class Mounter #:nodoc:
    attr_reader :column, :record, :remote_urls, :integrity_error, :processing_error, :download_error
    attr_accessor :remove

    def initialize(record, column, options={})
      @record = record
      @column = column
      @options = record.class.uploader_options[column]
    end

    def blank_uploader
      record.class.uploaders[column].new(record, column)
    end

    def identifiers
      if remove?
        nil
      else
        uploaders.map(&:identifier)
      end
    end

    def read_identifiers
      [record.read_uploader(serialization_column)].flatten.reject(&:blank?)
    end

    def uploaders
      @uploaders ||= read_identifiers.map do |identifier|
        uploader = blank_uploader
        uploader.retrieve_from_store!(identifier) if identifier.present?
        uploader
      end
    end

    def cache(new_files)
      @uploaders = new_files.map do |new_file|
        uploader = blank_uploader
        uploader.cache!(new_file)
        uploader
      end

      @integrity_error = nil
      @processing_error = nil
    rescue CarrierWave::IntegrityError => e
      @integrity_error = e
      raise e unless option(:ignore_integrity_errors)
    rescue CarrierWave::ProcessingError => e
      @processing_error = e
      raise e unless option(:ignore_processing_errors)
    end

    def cache_names
      uploaders.map(&:cache_name)
    end

    def cache_names=(cache_names)
      return if uploaders.any?(&:cached?)
      @uploaders = cache_names.map do |cache_name|
        uploader = blank_uploader
        uploader.retrieve_from_cache!(cache_name)
        uploader
      end
    rescue CarrierWave::InvalidParameter
    end

    def remote_urls=(urls)
      return if urls.all?(&:blank?)

      @remote_urls = urls
      @download_error = nil
      @integrity_error = nil

      @uploaders = urls.map do |url|
        uploader = blank_uploader
        uploader.download!(url)
        uploader
      end

    rescue CarrierWave::DownloadError => e
      @download_error = e
      raise e unless option(:ignore_download_errors)
    rescue CarrierWave::ProcessingError => e
      @processing_error = e
      raise e unless option(:ignore_processing_errors)
    rescue CarrierWave::IntegrityError => e
      @integrity_error = e
      raise e unless option(:ignore_integrity_errors)
    end

    def store!
      if remove?
        remove!
      else
        uploaders.reject(&:blank?).each(&:store!)
      end
    end

    def urls(*args)
      uploaders.map { |u| u.url(*args) }
    end

    def blank?
      uploaders.empty?
    end

    def remove?
      remove.present? && remove !~ /\A0|false$\z/
    end

    def remove!
      uploaders.reject(&:blank?).each(&:remove!)
    end

    def serialization_column
      option(:mount_on) || column
    end

    attr_accessor :uploader_options

  private

    def option(name)
      self.uploader_options ||= {}
      self.uploader_options[name] ||= record.class.uploader_option(column, name)
    end

  end # Mounter
end # CarrierWave