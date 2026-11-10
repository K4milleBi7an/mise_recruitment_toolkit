# frozen_string_literal: true

require "sinatra/base"
require_relative "lib/toolkit"
require_relative "lib/presets"

Regexp.timeout = 2 # a runaway find-and-replace pattern can't hang the server

module Mise
  NAME = "Mise"
  MAX_INPUT = 500_000 # characters

  class App < Sinatra::Base
    set :root, __dir__
    set :erb, escape_html: true

    helpers do
      def field(index, key) = "steps[#{index}][args][#{key}]"
      def field_id(index, key) = "s#{index}-#{key}"
      def count_of(number, noun) = "#{number} #{noun}#{'s' unless number == 1}"
      def links_in(text) = text.to_s.scan(%r{https?://\S+}).uniq.first(30)
    end

    # Nothing is stored and candidate text only ever travels in the POST body,
    # so it stays out of the address bar, browser history and server logs.
    before { headers "Cache-Control" => "no-store", "Referrer-Policy" => "no-referrer" }

    get "/" do
      preset = PRESETS[params["preset"].to_s]
      @recipe = preset ? preset.recipe : Toolkit::Recipe.decode(params["r"])
      @input = preset ? preset.sample : ""
      @result = @recipe.bake(@input) unless @recipe.empty?
      erb :index
    end

    post "/" do
      @input = params["input"].to_s.gsub("\r\n", "\n")[0, MAX_INPUT]
      @recipe = Toolkit::Recipe.from_params(params["steps"])
      action, target = params["do"].to_s.split(":", 2)

      case action
      when "add" then @recipe.add(target)
      when "remove" then @recipe.remove(target.to_i)
      when "up" then @recipe.move(target.to_i, -1)
      when "down" then @recipe.move(target.to_i, 1)
      when "clear" then @recipe = Toolkit::Recipe.new
      when "swap" # the output becomes the input for a fresh recipe
        @input = @recipe.bake(@input).output
        @recipe = Toolkit::Recipe.new
      end

      @result = @recipe.bake(@input)

      if action == "download"
        attachment "mise-output.txt"
        content_type "text/plain", charset: "utf-8"
        return @result.output
      end

      erb :index
    end
  end
end
