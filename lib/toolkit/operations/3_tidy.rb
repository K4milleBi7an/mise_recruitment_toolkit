# frozen_string_literal: true

module Toolkit
  NAME_PARTICLES = %w[van der den de du le la von da dos].freeze

  def self.name_case(line)
    line.split(/(\s+|-)/).each_with_index.map do |part, index|
      next part if part.match?(/\A(\s+|-)\z/)

      lower = part.downcase
      next lower if index.positive? && NAME_PARTICLES.include?(lower)

      lower.sub(/\A(mc|o')?(\p{L})/) { "#{Regexp.last_match(1)&.capitalize}#{Regexp.last_match(2).upcase}" }
    end.join
  end

  operation :trim do
    name "Trim whitespace"
    category "Tidy"
    description "Removes stray spaces at line ends, doubled spaces and blank lines."
    arg :blank_lines, :checkbox, label: "Drop blank lines", default: true
    arg :collapse, :checkbox, label: "Collapse repeated spaces", default: true
    run do |input, args|
      rows = Util.lines(input).map(&:strip)
      rows.map! { |r| r.gsub(/[ \t]{2,}/, " ") } if args[:collapse]
      rows.reject!(&:empty?) if args[:blank_lines]
      rows.join("\n")
    end
  end

  operation :dedupe do
    name "Remove duplicate lines"
    category "Tidy"
    description "Keeps the first copy of each line."
    arg :ignore_case, :checkbox, label: "Ignore capitals", default: true
    run do |input, args|
      Util.lines(input).uniq { |l| args[:ignore_case] ? l.strip.downcase : l.strip }.join("\n")
    end
  end

  operation :sort do
    name "Sort lines"
    category "Tidy"
    description "Alphabetical order, ignoring capitals."
    arg :direction, :select, label: "Order", default: "az", options: [%w[az A\ to\ Z], %w[za Z\ to\ A]]
    run do |input, args|
      rows = Util.lines(input).sort_by(&:downcase)
      (args[:direction] == "za" ? rows.reverse : rows).join("\n")
    end
  end

  operation :change_case do
    name "Fix capitalisation"
    category "Tidy"
    description "Name Case handles van der Merwe, McKenzie and O'Brien."
    arg :mode, :select, label: "Style", default: "name",
        options: [%w[name Name\ Case], %w[upper UPPER\ CASE], %w[lower lower\ case], %w[sentence Sentence\ case]]
    run do |input, args|
      Util.lines(input).map do |line|
        case args[:mode]
        when "upper" then line.upcase
        when "lower" then line.downcase
        when "sentence" then line.downcase.sub(/\p{L}/, &:upcase)
        else Toolkit.name_case(line)
        end
      end.join("\n")
    end
  end

  operation :filter do
    name "Filter lines"
    category "Tidy"
    description "Keeps (or drops) the lines that mention a word."
    arg :term, :text, label: "Word or phrase", default: "", placeholder: "gmail.com"
    arg :mode, :select, label: "Lines that match", default: "keep", options: [%w[keep Keep], %w[drop Drop]]
    run do |input, args|
      term = args[:term].strip.downcase
      raise Error, "Type a word or phrase to filter on." if term.empty?

      rows = Util.lines(input)
      (args[:mode] == "drop" ? rows.reject { |l| l.downcase.include?(term) } : rows.select { |l| l.downcase.include?(term) }).join("\n")
    end
  end

  operation :replace do
    name "Find and replace"
    category "Tidy"
    description "Swaps one piece of text for another everywhere."
    arg :find, :text, label: "Find", default: ""
    arg :with, :text, label: "Replace with", default: ""
    arg :regex, :checkbox, label: "Find is a regular expression", default: false
    arg :ignore_case, :checkbox, label: "Ignore capitals", default: true
    run do |input, args|
      raise Error, "Type something to find." if args[:find].empty?

      source = args[:regex] ? args[:find] : Regexp.escape(args[:find])
      input.gsub(Regexp.new(source, args[:ignore_case] ? Regexp::IGNORECASE : 0), args[:with])
    rescue Regexp::TimeoutError
      raise Error, "That pattern took too long to run. Try a simpler one."
    end
  end

  operation :join do
    name "Join lines"
    category "Tidy"
    description "Puts a list on one line, e.g. emails ready for a BCC field."
    arg :separator, :text, label: "Separator", default: "; "
    run { |input, args| Util.filled_lines(input).join(args[:separator]) }
  end
end
