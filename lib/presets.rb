# frozen_string_literal: true

# Ready-made recipes with made-up sample input, so a new coordinator can see
# what a recipe does before pasting real data. All names and details are fictional.
module Mise
  Preset = Struct.new(:title, :blurb, :steps, :sample) do
    def recipe = Toolkit::Recipe.new(steps.filter_map { |op, args| Toolkit::Recipe.build_step(op, args.transform_keys(&:to_s)) })
  end

  PRESETS = {
    "xray" => Preset.new(
      "X-ray a LinkedIn search", "Job titles in, clickable search links out.",
      [[:xray, { location: "Cape Town", must: "fintech" }], [:search_links, { engine: "google" }]],
      "Talent Acquisition Specialist\nRecruiter\nTalent Partner"
    ),
    "contacts" => Preset.new(
      "Tidy a contact list", "Pull emails out of a messy paste, de-duplicated and sorted.",
      [[:extract_emails, {}], [:sort, {}], [:join, {}]],
      "Thandi Mokoena <Thandi.Mokoena@example.com>, 082 555 0142\nPieter VAN DER MERWE - pieter@example.co.za;\n" \
      "thandi.mokoena@example.com (duplicate)\nAisha Patel | aisha.patel@example.org | +27 (0)21 555 0199"
    ),
    "blind" => Preset.new(
      "Blind a CV extract", "Mask contact details and ID numbers before sharing with a panel.",
      [[:redact, {}]],
      "SIPHO DLAMINI\nID: 9001010000000 | Cell: 082 555 0142 | sipho.dlamini@example.com\n" \
      "https://www.linkedin.com/in/sipho-dlamini-example\n\nFive years in payments operations; led a team of six."
    ),
    "confirmations" => Preset.new(
      "Interview confirmations", "One message per candidate from a pasted spreadsheet.",
      [[:mail_merge, {}]],
      "First Name,Role,Date,Time\nThandi,Product Analyst,Thu 12 Nov,09:00\nPieter,Product Analyst,Thu 12 Nov,10:00"
    ),
    "panel_day" => Preset.new(
      "Plan a panel morning", "Assign candidates to back-to-back slots.",
      [[:change_case, {}], [:slots, { date: "2026-11-12" }]],
      "thandi mokoena\nPIETER VAN DER MERWE\naisha patel"
    ),
    "job_ad" => Preset.new(
      "Check a job ad", "Flag coded wording before it goes live.",
      [[:coded_words, {}]],
      "We need a young, competitive rockstar who will dominate the market. You are an ambitious, " \
      "independent leader who is also supportive of the team."
    )
  }.freeze
end
