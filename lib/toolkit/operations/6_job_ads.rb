# frozen_string_literal: true

module Toolkit
  # Word stems from Gaucher, Friesen & Kay (2011), "Evidence that gendered wording in job
  # advertisements exists and sustains gender inequality". A prompt to reread, not a verdict.
  MASCULINE_STEMS = %w[
    active adventurous aggress ambitio analy assert athlet autonom boast challeng compet confident courag
    decide decisive decision determin dominan domina force greedy headstrong hierarch hostil impulsive
    independen individual intellect lead logic masculine objective opinion outspoken persist principle
    reckless stubborn superior self-confiden self-sufficien self-relian
  ].freeze
  FEMININE_STEMS = %w[
    affectionate child cheer collab commit communal compassion connect considerate cooperat depend emotiona
    empath feminine flatterable gentle honest interpersonal interdependen kind kinship loyal modesty nag
    nurtur pleasant polite quiet respon sensitiv submissive support sympath tender together trust understand
    warm whin yield
  ].freeze
  SECOND_LOOK = {
    "young" => "age", "youthful" => "age", "energetic" => "age", "digital native" => "age",
    "recent graduate" => "age", "mature" => "age", "rockstar" => "jargon", "ninja" => "jargon",
    "guru" => "jargon", "native english" => "origin", "mother tongue" => "origin",
    "able-bodied" => "disability", "manpower" => "gendered term", "salesman" => "gendered term",
    "chairman" => "gendered term"
  }.freeze

  def self.tally(words, stems)
    words.select { |w| stems.any? { |stem| w.start_with?(stem) } }.tally.sort_by { |word, count| [-count, word] }
         .map { |word, count| count > 1 ? "#{word} ×#{count}" : word }
  end

  def self.money(amount)
    whole, cents = format("%.2f", amount).split(".")
    "R #{whole.reverse.scan(/\d{1,3}/).join(' ').reverse}#{cents == '00' ? '' : ".#{cents}"}"
  end

  operation :coded_words do
    name "Flag coded wording"
    category "Job ads"
    description "Lists gender-coded words (from published research) and phrases worth a second look in a job ad."
    run do |input, _|
      raise Error, "Paste a job ad first." if input.strip.empty?

      words = input.downcase.scan(/[a-z]+(?:-[a-z]+)*/)
      masculine = Toolkit.tally(words, MASCULINE_STEMS)
      feminine = Toolkit.tally(words, FEMININE_STEMS)
      flagged = SECOND_LOOK.select { |phrase, _| input.downcase.match?(/\b#{Regexp.escape(phrase)}\b/) }
      total = ->(list) { list.sum { |entry| entry[/×(\d+)/, 1]&.to_i || 1 } }
      m, f = total.(masculine), total.(feminine)
      lean = if m == f then "balanced"
             elsif m > f then "leans masculine-coded"
             else "leans feminine-coded"
             end
      [
        "Overall: #{lean} (#{m} masculine-coded, #{f} feminine-coded)",
        "",
        "Masculine-coded: #{masculine.empty? ? 'none found' : masculine.join(', ')}",
        "Feminine-coded: #{feminine.empty? ? 'none found' : feminine.join(', ')}",
        "Worth a second look: #{flagged.empty? ? 'none found' : flagged.map { |p, why| "“#{p}” (#{why})" }.join(', ')}"
      ].join("\n")
    end
  end

  operation :text_stats do
    name "Count words"
    category "Job ads"
    description "Words, characters and reading time."
    run do |input, _|
      words = input.split.size
      minutes = (words / 200.0).ceil
      [
        "Words: #{words}",
        "Characters: #{input.length}",
        "Lines: #{input.lines.size}",
        "Reading time: about #{minutes} #{minutes == 1 ? 'minute' : 'minutes'}"
      ].join("\n")
    end
  end

  operation :salary do
    name "Convert salary"
    category "Job ads"
    description "One amount per line (R45 000, 540k, 259.62). Gross figures only — no tax or deductions."
    arg :period, :select, label: "Amounts are", default: "monthly",
        options: [%w[annual Per\ year], %w[monthly Per\ month], %w[hourly Per\ hour]]
    arg :hours, :number, label: "Hours per week", default: 40
    run do |input, args|
      raise Error, "Hours per week should be between 1 and 60." unless args[:hours].between?(1, 60)

      Util.filled_lines(input).map do |line|
        text = line.downcase.gsub(/[r\s]/, "")
        text = text.match?(/,\d{2}\z/) ? text.sub(/,(\d{2})\z/, '.\1') : text.delete(",")
        match = text.match(/\A(\d+(?:\.\d+)?)(k)?\z/) or raise Error, "Couldn't read “#{line}” as an amount."
        amount = match[1].to_f * (match[2] ? 1000 : 1)
        yearly_hours = args[:hours] * 52.0
        annual = case args[:period]
                 when "annual" then amount
                 when "monthly" then amount * 12
                 else amount * yearly_hours
                 end
        "#{Toolkit.money(annual)} per year  |  #{Toolkit.money(annual / 12)} per month  |  #{Toolkit.money(annual / yearly_hours)} per hour"
      end.join("\n")
    end
  end
end
