# frozen_string_literal: true

require "json"
require "base64"
require "date"
require "csv"

# The engine: a registry of operations and a Recipe that pipes text through them.
# Nothing in here knows about HTTP, so it can be lifted into Rails or a CLI as-is.
module Toolkit
  # Raise this from an operation to show the user a friendly message.
  class Error < StandardError; end

  MAX_STEPS = 30
  REGISTRY = {} # id => Operation, in registration order

  Arg = Struct.new(:key, :type, :label, :default, :options, :placeholder, :hint, keyword_init: true) do
    def option_pairs = Array(options).map { |o| o.is_a?(Array) ? o.map(&:to_s) : [o.to_s, o.to_s] }

    # What the HTML form should hold for this argument's default.
    def default_string
      type == :checkbox ? (default ? "1" : "0") : default.to_s
    end
  end

  class Operation
    attr_reader :id, :args

    def initialize(id, &definition)
      @id = id
      @args = []
      instance_eval(&definition)
    end

    def name(value = nil) = value ? @name = value : @name
    def category(value = nil) = value ? @category = value : @category
    def description(value = nil) = value ? @description = value : @description

    # Types: :text, :textarea, :number, :checkbox, :select, :date, :time
    def arg(key, type = :text, **options)
      @args << Arg.new(key: key.to_s, type: type, **options)
    end

    def run(&block) = @runner = block

    def defaults = @args.to_h { |a| [a.key, a.default_string] }

    def call(input, raw_args = {})
      @runner.call(input.to_s, coerce(raw_args || {})).to_s
    end

    private

    # Form values arrive as strings; turn them into what the run block expects.
    def coerce(raw)
      @args.to_h do |a|
        value = raw.key?(a.key) ? raw[a.key].to_s : a.default_string
        value =
          case a.type
          when :checkbox then value == "1"
          when :number
            Integer(value.strip, exception: false) or raise Error, "“#{a.label}” needs a whole number."
          when :select then a.option_pairs.map(&:first).include?(value) ? value : a.default_string
          else value
          end
        [a.key.to_sym, value]
      end
    end
  end

  def self.operation(id, &definition)
    REGISTRY[id.to_s] = Operation.new(id.to_s, &definition)
  end

  def self.categories = REGISTRY.values.group_by(&:category)

  Step = Struct.new(:operation, :args, :off)
  Report = Struct.new(:status, :message) # status: :ok, :error, :skipped
  Result = Struct.new(:output, :reports)

  class Recipe
    attr_reader :steps

    def initialize(steps = []) = @steps = steps.first(MAX_STEPS)

    # From the nested form params: {"0" => {"op" => "...", "args" => {...}, "off" => "1"}}
    def self.from_params(params)
      return new unless params.is_a?(Hash)

      rows = params.sort_by { |index, _| index.to_i }.map { |_, row| row }
      new(rows.filter_map { |row| build_step(row["op"], row["args"], row["off"] == "1") if row.is_a?(Hash) })
    end

    # From a shareable link. Holds operations and settings only — never the input text.
    def self.decode(token)
      rows = JSON.parse(Base64.urlsafe_decode64(token.to_s))
      new(rows.filter_map { |op, args, off| build_step(op, args, off == 1) })
    rescue ArgumentError, JSON::ParserError, NoMethodError, TypeError
      new
    end

    def self.build_step(op_id, args, off = false)
      operation = REGISTRY[op_id.to_s] or return
      given = args.is_a?(Hash) ? args : {}
      clean = operation.defaults.to_h { |key, default| [key, given.fetch(key, default).to_s[0, 5000]] }
      Step.new(operation, clean, off)
    end

    def encode
      Base64.urlsafe_encode64(JSON.generate(steps.map { |s| [s.operation.id, s.args, s.off ? 1 : 0] }), padding: false)
    end

    def add(op_id)
      step = self.class.build_step(op_id, nil)
      @steps << step if step && @steps.size < MAX_STEPS
    end

    def remove(index) = @steps.delete_at(index)

    def move(index, by)
      target = index + by
      return unless @steps[index] && target.between?(0, @steps.size - 1)

      @steps[index], @steps[target] = @steps[target], @steps[index]
    end

    def empty? = @steps.empty?

    # Pipe the input through each step. Stops at the first step that fails.
    def bake(input)
      text = input.to_s
      halted = false
      reports = steps.map do |step|
        next Report.new(:skipped, step.off ? "Switched off" : "Not run") if step.off || halted

        begin
          text = step.operation.call(text, step.args)
          Report.new(:ok, Util.size_of(text))
        rescue Error, RegexpError => e
          halted = true
          Report.new(:error, e.message)
        rescue StandardError => e
          halted = true
          Report.new(:error, "Something went wrong in this step (#{e.class}).")
        end
      end
      Result.new(text, reports)
    end
  end

  # Small helpers shared by operations.
  module Util
    module_function

    def lines(text) = text.to_s.lines.map(&:chomp)
    def filled_lines(text) = lines(text).map(&:strip).reject(&:empty?)
    def list(text) = text.to_s.split(/[,\n]/).map(&:strip).reject(&:empty?)

    def size_of(text)
      count = text.lines.size
      "#{count} #{count == 1 ? 'line' : 'lines'} out"
    end

    # Wrap in quotes when a term has spaces or punctuation, as search engines expect.
    def quote(term, always: false)
      term = term.delete('"').strip
      always || term.match?(/[^\w#+.]/) ? %("#{term}") : term
    end

    # Reads comma, semicolon (common from South African Excel), tab or pipe separated text.
    def table(text)
      text = text.to_s.delete_prefix("﻿").strip
      raise Error, "Paste some CSV with a header row first." if text.empty?

      first = text.lines.first
      separator = [",", ";", "\t", "|"].max_by { |s| first.count(s) }
      CSV.parse(text, col_sep: separator, headers: true, skip_blanks: true, liberal_parsing: true)
    rescue CSV::MalformedCSVError => e
      raise Error, "Couldn't read that as CSV: #{e.message}"
    end

    def parse_date(text)
      text = text.to_s.strip
      ["%Y-%m-%d", "%d/%m/%Y", "%d-%m-%Y", "%d %b %Y", "%d %B %Y"].each do |format|
        return Date.strptime(text, format)
      rescue Date::Error
        next
      end
      raise Error, "Couldn't read “#{text}” as a date. Try 2026-11-12 or 12/11/2026."
    end

    def parse_clock(text, label)
      match = text.to_s.strip.match(/\A(\d{1,2})[:h.](\d{2})\z/) or raise Error, "“#{label}” should look like 09:00."
      hours, minutes = match[1].to_i, match[2].to_i
      raise Error, "“#{label}” isn't a real time." unless hours < 24 && minutes < 60

      hours * 60 + minutes
    end

    def clock(minutes) = format("%02d:%02d", minutes / 60, minutes % 60)
  end
end

Dir[File.join(__dir__, "toolkit", "operations", "*.rb")].sort.each { |file| require file }
