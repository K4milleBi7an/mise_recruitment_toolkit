# frozen_string_literal: true

module Toolkit
  XRAY_SITES = {
    "linkedin" => ["LinkedIn profiles", "site:linkedin.com/in"],
    "github" => ["GitHub", "site:github.com"],
    "stackoverflow" => ["Stack Overflow users", "site:stackoverflow.com/users"],
    "behance" => ["Behance", "site:behance.net"],
    "dribbble" => ["Dribbble", "site:dribbble.com"],
    "none" => ["No site filter", ""]
  }.freeze

  SEARCH_ENGINES = {
    "google" => "https://www.google.com/search?q=",
    "bing" => "https://www.bing.com/search?q=",
    "duckduckgo" => "https://duckduckgo.com/?q="
  }.freeze

  operation :boolean_builder do
    name "Build Boolean string"
    category "Sourcing"
    description "Turns a list of titles or skills (one per line) into a Boolean group."
    arg :operator, :select, label: "Join with", default: "OR", options: %w[OR AND]
    arg :quote_all, :checkbox, label: "Quote every term", default: false
    arg :brackets, :checkbox, label: "Wrap in brackets", default: true
    run do |input, args|
      terms = Util.filled_lines(input).uniq.map { |t| Util.quote(t, always: args[:quote_all]) }
      raise Error, "Add at least one term, one per line." if terms.empty?

      joined = terms.join(" #{args[:operator]} ")
      args[:brackets] && terms.size > 1 ? "(#{joined})" : joined
    end
  end

  operation :xray do
    name "X-ray search query"
    category "Sourcing"
    description "Job titles in (one per line), a site: search query out. Uses public search engines; no scraping."
    arg :site, :select, label: "Search within", default: "linkedin", options: XRAY_SITES.map { |id, (label, _)| [id, label] }
    arg :location, :text, label: "Location", default: "South Africa", placeholder: "Cape Town, Johannesburg"
    arg :must, :text, label: "Must mention", default: "", placeholder: "Greenhouse, fintech", hint: "Comma separated. All must appear."
    arg :exclude, :text, label: "Exclude", default: "", placeholder: "jobs, intern", hint: "Comma separated."
    run do |input, args|
      titles = Util.filled_lines(input).uniq.map { |t| Util.quote(t, always: true) }
      raise Error, "Add at least one job title, one per line." if titles.empty?

      locations = Util.list(args[:location]).map { |l| Util.quote(l, always: true) }
      parts = [XRAY_SITES.fetch(args[:site]).last]
      parts << (titles.size > 1 ? "(#{titles.join(' OR ')})" : titles.first)
      parts << (locations.size > 1 ? "(#{locations.join(' OR ')})" : locations.first)
      parts.concat(Util.list(args[:must]).map { |m| Util.quote(m) })
      parts.concat(Util.list(args[:exclude]).map { |e| "-#{Util.quote(e)}" })
      parts.compact.reject(&:empty?).join(" ")
    end
  end

  operation :search_links do
    name "Search engine links"
    category "Sourcing"
    description "Turns each line into a ready-to-click search link."
    arg :engine, :select, label: "Engine", default: "all",
        options: [%w[all All\ three], %w[google Google], %w[bing Bing], %w[duckduckgo DuckDuckGo]]
    run do |input, args|
      engines = args[:engine] == "all" ? SEARCH_ENGINES.keys : [args[:engine]]
      queries = Util.filled_lines(input)
      raise Error, "Nothing to search for yet." if queries.empty?

      queries.flat_map { |q| engines.map { |e| SEARCH_ENGINES[e] + URI.encode_www_form_component(q) } }.join("\n")
    end
  end

  operation :linkedin_urls do
    name "Clean LinkedIn profile URLs"
    category "Sourcing"
    description "Finds LinkedIn profile links in any text and strips tracking junk and country subdomains."
    run do |input, _|
      input.scan(%r{linkedin\.com/in/([^\s/?#"'<>),]+)}i).flatten
           .map { |slug| "https://www.linkedin.com/in/#{slug.downcase}" }.uniq.join("\n")
    end
  end
end
