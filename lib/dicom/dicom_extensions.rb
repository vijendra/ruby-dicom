# encoding: UTF-8

## I've put all the extensions I've made to ruby-dicom
## in this file initially. These may be incorporated into
## ruby-dicom when things are more final and properly discussed
## in the community. /John Axel Eriksson, john@insane.se, http://github.com/johnae

module DICOM

  class << self

    @@tag_or_name = :name

    def key_use_tags
      @@tag_or_name = :tag
    end

    def key_use_names
      @@tag_or_name = :name
    end

    def key_use_method_names
      @@tag_or_name = :name_as_method
    end

    def tag_or_name
      @@tag_or_name
    end

  end


  class DLibrary

    alias_method :initialize_original, :initialize

    attr_reader :method_name_conversion_table, :name_method_conversion_table

    def initialize
      initialize_original
      create_method_conversion_table
    end

    # Returns the tag that matches the supplied data element name, by searching the Ruby DICOM dictionary.
    # Returns nil if no match is found.
    #
    # === Parameters
    #
    # * <tt>name</tt> -- String. A data element name.
    #

    def get_tag(name)
      tag = nil
      name = name.to_s.downcase
      @tag_name_pairs_cache ||= Hash.new
      return @tag_name_pairs_cache[name] unless @tag_name_pairs_cache[name].nil?
      @tags.each_pair do |key, value|
        next unless value[1].downcase == name
        tag = key
        break
      end
      @tag_name_pairs_cache[name]=tag
      return tag
    end

    def create_method_conversion_table
      if @method_name_conversion_table.nil?
        @method_name_conversion_table = Hash.new
        @name_method_conversion_table = Hash.new
        @tags.each_pair do |key,value|
          original = value[1]
          method_name = original.dicom_methodize
          @method_name_conversion_table[original.to_sym] = method_name.to_sym
          @name_method_conversion_table[method_name.to_sym] = original
        end
      end
    end

    def as_method(value)
      case true
      when value.tag?
        name, vr = get_name_vr(value)
        @method_name_conversion_table[name.to_sym]
      when value.dicom_name?
        @method_name_conversion_table[value.to_sym]
      when value.dicom_method?
        @name_method_conversion_table.has_key?(value.to_sym) ? value.to_sym : nil
      else
        nil
      end
    end

    def as_name(value)
      case true
      when value.tag?
        name, vr = get_name_vr(value)
        name
      when value.dicom_name?
        @method_name_conversion_table.has_key?(value.to_sym) ? value.to_s : nil
      when value.dicom_method?
        @name_method_conversion_table[value.to_sym]
      else
        nil
      end
    end

    def as_tag(value)
      case true
      when value.tag?
        name, vr = get_name_vr(value)
        name.nil? ? nil : value
      when value.dicom_name?
        get_tag(value)
      when value.dicom_method?
        get_tag(@name_method_conversion_table[value.to_sym])
      else
        nil
      end
    end

  end


  module Elements

    def name_as_method
      LIBRARY.as_method(self.name)
    end

  end


  class DataElement

    def inspect
      to_hash.inspect
    end

    def to_yaml
      to_hash.to_yaml
    end

    ## doesn't inherit from
    ## super parent so this
    ## needs it's own implementation
    ## which is ridiculously simple

    def to_hash
      value
    end

    def to_json
      to_hash.to_json
    end

    def name_as_method
      LIBRARY.as_method(@name)
    end

  end


  class DObject < SuperItem

    alias_method :read_success?, :read_success
    alias_method :write_success?, :write_success

  end


  class DRead

    def open_file(file)
      ## can now read from any kind of uri using open-uri, limited to http for now though
      if file.index('http')==0
        @retrials = 0
        begin
          @file = open(file, 'rb') # binary encoding (ASCII-8BIT)
        rescue Exception => e
          if @retrials>3
            @retrials = 0
            raise NonExistantFileException.new, '[RubyDicom] File does not exist'
          else
            puts "Warning: Exception in RubyDicom when loading dicom from: #{file}"
            puts "Retrying... #{@retrials}"
            @retrials+=1
            retry
          end
        end
      elsif File.exist?(file)
        if File.readable?(file)
          if not File.directory?(file)
            if File.size(file) > 8
              @file = File.new(file, "rb")
            else
              @msg << "Error! File is too small to contain DICOM information (#{file})."
            end
          else
            @msg << "Error! File is a directory (#{file})."
          end
        else
          @msg << "Error! File exists but I don't have permission to read it (#{file})."
        end
      else
        @msg << "Error! The file you have supplied does not exist (#{file})."
      end
    end

  end


  class SuperParent

    def method_missing(sym, *args, &block)
      tag = LIBRARY.as_tag(sym.to_s) || LIBRARY.as_tag(sym.to_s[0..-2])
      unless tag.nil?
        if sym.to_s[-1..-1] == '?'
          return self.exists?(tag)
        elsif sym.to_s[-1..-1] == '='
          unless args.length==0 || args[0].nil?
            ### MUST FIX! Other elements can also be added
            return self.add DataElement.new(tag, *args)
          else
            return self.remove(tag)
          end
        else
          return self[tag] rescue nil
        end
      end
      super
    end

    def respond_to?(method_name)
      return true unless LIBRARY.as_tag(method_name.to_s).nil?
      return true unless LIBRARY.as_tag(method_name.to_s[0..-2]).nil?
      super
    end

    def inspect
      to_hash.inspect
    end

    def to_yaml
      to_hash.to_yaml
    end

    def to_hash
      as_hash = nil
      unless children?
        ## this may look weird but is really
        ## just a fix for when there is no name
        ## corresponding to the tag - then we
        ## want to use the tag
        as_hash = (self.tag.private?) ? self.tag : self.send(DICOM.tag_or_name)
      else
        as_hash = Hash.new
        children.each do |child|
          ## this may look weird but is really
          ## just a fix for when there is no name
          ## corresponding to the tag - then we
          ## want to use the tag
          if child.tag.private?
            hash_key = child.tag
          elsif child.is_a?(Item)
            hash_key = "Item #{child.index}"
          else
            hash_key = child.send(DICOM.tag_or_name)
          end
          as_hash[hash_key] = child.to_hash
        end
      end
      return as_hash
    end

    def to_json
      to_hash.to_json
    end

    def elements
      children.select { |child| child.is_a?(DataElement)}
    end

    def elements?
      elements.any?
    end

    def each_sequence(&block)
      sequences.each_with_index(&block) if children?
    end

    def each_element(&block)
      elements.each_with_index(&block) if children?
    end

    def each_item(&block)
      items.each_with_index(&block) if children?
    end

    def items
      children.select { |child| child.is_a?(Item)}
    end

    def items?
      items.any?
    end

    def each_tag(&block)
      @tags.each_key(&block)
    end

    def each(&block)
      children.each_with_index(&block)
    end

    def each(&block)
      children.each_with_index(&block)
    end

    def sequences
      children.select { |child| child.is_a?(Sequence) }
    end

    def sequences?
      sequences.any?
    end

    def item(index=0)
      items[index]
    end

  end


  class NonExistantFileException < Exception
  end


  ## must do this
  ## it's only done
  ## once when the module is loaded
  ## so there isn't really
  ## any large overhead
  remove_const(:LIBRARY)
  LIBRARY =  DICOM::DLibrary.new

end