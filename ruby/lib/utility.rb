# Created by Satoshi Nakagawa.
# You can redistribute it and/or modify it under the Ruby's license or the GPL2.

class String
  def first_char
    scan(/./)[0]
  end
  
  def each_char
    scan(/./) {|c| yield c }
  end
  
  def token!
    if / *([^ ]+) */ =~ self
      self[0...$&.size] = ''
      $1
    else
      replace('')
    end
  end
  
  def downcase_first
    empty? ? '' : self[0..0].downcase + self[1..-1]
  end
  
  def underscorize
    gsub(" ", "_").downcase
  end  
  
  def channelname?
    if /\A[#&+!]/ =~ self
      true
    else
      false
    end
  end
  
  def modechannelname?
    if /\A[#&!]/ =~ self
      true
    else
      false
    end
  end
  
  def server?
    include?('.')
  end
  
  def safe_filename
    gsub(/[:\/]/, '_')
  end
  
  def to_ns
    NSMutableString.stringWithString(self)
  end
  
  def expand_path
    to_ns.stringByExpandingTildeInPath.to_s
  end
  
  def collapse_path
    to_ns.stringByAbbreviatingWithTildeInPath.to_s
  end
end

class Array
  alias :orginal_index :index
  def index(*args)
    if block_given?
      each_with_index {|e,i| return i if yield e }
      nil
    else
      orginal_index(*args)
    end
  end
  
  def to_indexset
    set = NSMutableIndexSet.alloc.init
    each {|i| set.addIndex(i) }
    set
  end
  
  def to_ns
    NSMutableArray.arrayWithArray(self)
  end
end

class Hash
  def to_ns
    NSMutableDictionary.dictionaryWithDictionary(self)
  end
end

class Numeric
  def grouped_by_comma
    s = to_s
    nil while s.gsub!(/(.*\d)(\d\d\d)/, '\1,\2')
    s
  end
end

module OSX
  class NSObject
    def to_ruby
      case self 
      when NSDate
        to_time
      when NSCFBoolean
        boolValue
      when NSNumber
        float? ? to_f : to_i
      when NSString
        to_s
      when NSAttributedString
        string.to_s
      when NSArray,NSIndexSet
        to_a.map {|x| x.is_a?(NSObject) ? x.to_ruby : x }
      when NSDictionary
        h = {}
        each do |x, y| 
          x = x.to_ruby if x.is_a?(NSObject)
          y = y.to_ruby if y.is_a?(NSObject)
          x = x.to_sym if x.is_a?(String)
          h[x] = y
        end
        h
      else
        self
      end
    end
  end
  
  class NSNumber
    def float?
      CFNumberIsFloatType(self)
    end
    
    def inspect
      "NS:#{to_ruby}"
    end
  end
  
  class NSString
    def inspect
      "NS:#{to_s.inspect}"
    end
  end
  
  class NSArray
    def inspect
      "NS:#{to_a.inspect}"
    end
  end
  
  class NSDictionary
    def inspect
      "NS:#{to_hash.inspect}"
    end
  end
  
  class NSIndexSet
    def inspect
      "#<#{self.class.to_s.gsub(/^OSX::/, '')} #{to_a.inspect}>"
    end
  end
  
  class NSSelectionArray
    # NSTextView.selectedRanges returns NSSelectionArray
    # workaround for Tiger
    def to_a
      ary = []
      (0...count).each {|i| ary << objectAtIndex(i) }
      ary
    end
  end
  
  class NSPoint
    def in(r); NSPointInRect(self, r); end
    def +(v)
      if v.is_a?(NSSize)
        NSPoint.new(x + v.width, y + v.height)
      else
        raise ArgumentException, "parameter should be NSSize"
      end
    end
    def -(v)
      if v.is_a?(NSSize)
        NSPoint.new(x - v.width, y - v.height)
      else
        raise ArgumentException, "parameter should be NSSize"
      end
    end

    def inspect
      "#<#{self.class.to_s.gsub(/^OSX::/, '')} (#{x}, #{y})>"
    end
  end
  
  class NSSize
    def /(v); NSSize.new(width / v, height / v); end
    def *(v); NSSize.new(width * v, height * v); end
    def +(v); NSSize.new(width + v, height + v); end
    def -(v); NSSize.new(width - v, height - v); end
    
    def self.from_dic(d); NSSize.new(d[:w], d[:h]); end
    def to_dic; { :w => width, :h => height }; end
    
    def inspect
      "#<#{self.class.to_s.gsub(/^OSX::/, '')} (#{width}, #{height})>"
    end
  end
  
  class NSRect
    def x=(v); origin.x = v; end
    def y=(v); origin.y = v; end
    def width=(v); size.width = v; end
    def height=(v); size.height = v; end
    def contain?(r)
      case r
      when NSRect; NSContainsRect(self, r)
      when NSPoint; NSPointInRect(r, self)
      else raise ArgumentException, "parameter should be NSRect or NSPoint"
      end
    end
    def center; origin + (size / 2.0); end
    def adjustInRect(r)
      n = dup
      n.x = r.x + r.width - n.width if r.x + r.width < n.x + n.width
      n.y = r.y + r.height - n.height if r.y + r.height < n.y + n.height
      n.x = r.x if n.x < r.x
      n.y = r.y if n.y < r.y
      n
    end
    def self.from_dic(d); NSRect.new(d[:x], d[:y], d[:w], d[:h]); end
    def to_dic; { :x => x, :y => y, :w => width, :h => height }; end
    def self.from_center(p, width, height)
      NSRect.new(p.x - width/2, p.y - height/2, width, height)
    end

    def inspect
      "#<#{self.class.to_s.gsub(/^OSX::/, '')} (#{x}, #{y}, #{width}, #{height})>"
    end
  end
  
  class NSRange
    def empty?; length == 0 || not_found?; end
    def not_found?; location == NSNotFound; end
    def size; length; end
    def size=(v); length = v; end
    def max; location + length; end
    def inspect
      "#<#{self.class.to_s.gsub(/^OSX::/, '')} (#{location}, #{length})>"
    end
  end
  
  class NSWindow
    def centerOfScreen
      scr = NSScreen.screens[0]
      if scr
        p = scr.visibleFrame.center
        p -= frame.size / 2
        setFrameOrigin(p)
      else
        center
      end
    end
    
    def centerOfWindow(window)
      p = window.frame.center
      p -= frame.size / 2
      scr = window.screen
      if scr
        sf = scr.visibleFrame
        f = frame
        f.origin = p
        unless sf.contain?(f)
          f = f.adjustInRect(sf)
          p = f.origin
        end
      end
      setFrameOrigin(p)
    end
  end
  
  class NSColor
    def self.from_rgb(red, green, blue, alpha=1.0)
      NSColor.colorWithCalibratedRed_green_blue_alpha(red/255.0, green/255.0, blue/255.0, alpha)
    end
    
    def self.from_css(str)
      return nil unless str
      str[0] = '' if str =~ /\A#/
      case str.size
      when 6
        r = str[0..1].to_i(16)
        g = str[2..3].to_i(16)
        b = str[4..5].to_i(16)
        from_rgb(r, g, b)
      when 3
        r = str[0..0].to_i(16)
        g = str[1..1].to_i(16)
        b = str[2..2].to_i(16)
        NSColor.colorWithCalibratedRed_green_blue_alpha(r/15.0, g/15.0, b/15.0, 1.0)
      else
        nil
      end
    end
    
    def inspect
      sprintf("#<%s (%1.1f, %1.1f, %1.1f, %1.1f)>", self.class.to_s.gsub(/^OSX::/, ''), redComponent*255.0, greenComponent*255.0, blueComponent*255.0, alphaComponent*255.0)
    end
  end
  
  module LanguageSupport
    def primary_language
      langs = NSUserDefaults.standardUserDefaults[:AppleLanguages]
      if langs
        langs[0].to_ruby
      else
        nil
      end
    end
    module_function :primary_language
  end
  
  class NSEvent
    def inspect
      "#<#{self.class.to_s.gsub(/^OSX::/, '')}:#{sprintf("0x%x", object_id)} type=#{_type_name}>"
    end
    
    private
    
    def _type_name
      EVENT_TYPE_MAP[oc_type] || 'Unknown'
    end
    
    EVENT_TYPE_MAP = {
      NSLeftMouseDown => 'NSLeftMouseDown',
      NSLeftMouseUp => 'NSLeftMouseUp',
      NSRightMouseDown => 'NSRightMouseDown',
      NSRightMouseUp => 'NSRightMouseUp',
      NSMouseMoved => 'NSMouseMoved',
      NSLeftMouseDragged => 'NSLeftMouseDragged',
      NSRightMouseDragged => 'NSRightMouseDragged',
      NSMouseEntered => 'NSMouseEntered',
      NSMouseExited => 'NSMouseExited',
      NSKeyDown => 'NSKeyDown',
      NSKeyUp => 'NSKeyUp',
      NSFlagsChanged => 'NSFlagsChanged',
      NSAppKitDefined => 'NSAppKitDefined',
      NSSystemDefined => 'NSSystemDefined',
      NSApplicationDefined => 'NSApplicationDefined',
      NSPeriodic => 'NSPeriodic',
      NSCursorUpdate => 'NSCursorUpdate',
      NSScrollWheel => 'NSScrollWheel',
      NSTabletPoint => 'NSTabletPoint',
      NSTabletProximity => 'NSTabletProximity',
      NSOtherMouseDown => 'NSOtherMouseDown',
      NSOtherMouseUp => 'NSOtherMouseUp',
      NSOtherMouseDragged => 'NSOtherMouseDragged',
    }
  end
  
  # for compatilibity
  if RUBYCOCOA_VERSION < '0.13.0'
    class NSPoint
      def dup; NSPoint.new(x, y); end
    end
    class NSSize
      def dup; NSSize.new(width, height); end
    end
    class NSRect
      def dup; NSRect.new(origin, size); end
    end
    class NSRange
      def dup; NSRange.new(location, length); end
    end
  end
end
