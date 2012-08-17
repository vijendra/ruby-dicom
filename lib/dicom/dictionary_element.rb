module DICOM

  # This class handles the various Element types (data, file meta, directory structuring)
  # found in the DICOM Data Dictionary.
  #
  class DictionaryElement

    # The element's name, e.g. 'SOP Instance UID'.
    attr_reader :name
    # The element's retired status string, i.e. an empty string or 'R'.
    attr_reader :retired
    # The element's tag, e.g. '0010,0010'.
    attr_reader :tag
    # The element's value multiplicity, e.g. '1', '2-n'.
    attr_reader :vm
    # The element's value representations, e.g. ['UL'], ['US', 'SS'].
    attr_reader :vrs

    # Creates a new dictionary element.
    #
    # @param [String] tag The element's tag.
    # @param [String] name The element's name.
    # @param [Array<String>] vrs The element's value representation(s).
    # @param [String] vm The element's value multiplicity.
    # @param [String] retired The element's retired status string.
    #
    def initialize(tag, name, vrs, vm, retired)
      @tag = tag
      @name = name
      @vrs = vrs
      @vm = vm
      @retired = retired
    end

    # Converts the retired status string to a boolean.
    #
    # @return [Boolean] true if the element is retired, and false if not.
    #
    def retired?
      @retired == 'R' ? true : false
    end

    # Extracts the first (default) value representation of the element's value representations.
    #
    # @return [String] the first value representation listed for this particular element
    #
    def vr
      @vrs[0]
    end

  end

end