# frozen_string_literal: true

ENV["RACK_ENV"] = "test"
require "minitest/autorun"
require "rack/test"
require_relative "../app"

class OperationsTest < Minitest::Test
  def run_op(id, input, args = {}) = Toolkit::REGISTRY.fetch(id.to_s).call(input, args.transform_keys(&:to_s))

  def test_every_operation_is_complete_and_survives_empty_input
    Toolkit::REGISTRY.each_value do |op|
      assert op.name && op.category && op.description, "#{op.id} is missing a name, category or description"
      begin
        op.call("")
      rescue Toolkit::Error
        # a friendly error is an acceptable answer to empty input
      end
    end
  end

  def test_xray
    out = run_op(:xray, "Recruiter\nTalent Partner", "location" => "Cape Town", "must" => "fintech", "exclude" => "jobs")
    assert_equal 'site:linkedin.com/in ("Recruiter" OR "Talent Partner") "Cape Town" fintech -jobs', out
  end

  def test_boolean_builder
    assert_equal '(Ruby OR "Ruby on Rails" OR C#)', run_op(:boolean_builder, "Ruby\nRuby on Rails\nC#")
  end

  def test_search_links
    assert_equal "https://www.google.com/search?q=site%3Agithub.com+%22ruby%22", run_op(:search_links, 'site:github.com "ruby"', "engine" => "google")
  end

  def test_linkedin_urls
    out = run_op(:linkedin_urls, "see https://za.linkedin.com/in/Jane-Doe-123/?originalSubdomain=za and linkedin.com/in/jane-doe-123")
    assert_equal "https://www.linkedin.com/in/jane-doe-123", out
  end

  def test_extract_emails
    assert_equal "a.b@example.com\nc@example.co.za", run_op(:extract_emails, "A.B@Example.com, <c@example.co.za>; a.b@example.com.")
  end

  def test_extract_phones
    text = "082 555 0142, +27 (0)21 555 0199, 0027825550142, (011) 555-0100, ID 9001010000000"
    assert_equal "+27825550142\n+27215550199\n+27115550100", run_op(:extract_phones, text)
    assert_equal "082 555 0142", run_op(:extract_phones, "+27825550142", "format" => "local")
  end

  def test_redact
    out = run_op(:redact, "ID 9001010000000, 082 555 0142, a@example.com, https://www.linkedin.com/in/a")
    assert_equal "ID [ID NUMBER REMOVED], [PHONE REMOVED], [EMAIL REMOVED], [LINK REMOVED]", out
  end

  def test_name_case
    assert_equal "Pieter van der Merwe\nSiobhan O'Brien\nAnne-Marie McKenzie", run_op(:change_case, "PIETER VAN DER MERWE\nsiobhan o'brien\nanne-marie mckenzie")
  end

  def test_dedupe_and_sort
    assert_equal "b\nA", run_op(:dedupe, "b\nA\na\nB ")
    assert_equal "A\nb", run_op(:sort, "b\nA")
  end

  def test_replace_rejects_bad_regex
    assert_raises(RegexpError) { run_op(:replace, "x", "find" => "(", "regex" => "1") }
    assert_equal "a-b", run_op(:replace, "a.b", "find" => ".", "with" => "-")
  end

  def test_csv_semicolons_and_column
    assert_equal "a@example.com\nb@example.com", run_op(:csv_column, "Name;Email\nA;a@example.com\nB;b@example.com", "column" => "email")
    assert_raises(Toolkit::Error) { run_op(:csv_column, "Name,Email\nA,a@x.com", "column" => "phone") }
  end

  def test_csv_to_markdown
    assert_equal "| A | B |\n| --- | --- |\n| 1 | 2 |", run_op(:csv_to_markdown, "A,B\n1,2")
  end

  def test_mail_merge
    out = run_op(:mail_merge, "First Name,Role\nThandi,Analyst\nPieter,Engineer", "template" => "Hi {{first_name}} ({{ Role }})", "divider" => "--")
    assert_equal "Hi Thandi (Analyst)\n--\nHi Pieter (Engineer)", out
    error = assert_raises(Toolkit::Error) { run_op(:mail_merge, "Name\nA", "template" => "{{surname}}") }
    assert_includes error.message, "{{name}}"
  end

  def test_time_zones
    out = run_op(:time_zones, "2026-11-12 14:00\n12/06/2026 14:00", "to" => "Europe/London")
    assert_equal "Thu 12 Nov 2026 14:00 SAST  →  Thu 12 Nov 12:00 GMT (Europe/London)\n" \
                 "Fri 12 Jun 2026 14:00 SAST  →  Fri 12 Jun 13:00 BST (Europe/London)", out
    assert_raises(Toolkit::Error) { run_op(:time_zones, "2026-11-12 14:00", "to" => "Mars/Olympus") }
  end

  def test_slots
    out = run_op(:slots, "Thandi\nPieter", "start" => "09:00", "finish" => "12:00", "length" => "45", "gap" => "15")
    assert_equal "09:00–09:45  Thandi\n10:00–10:45  Pieter\n11:00–11:45  (open)", out
  end

  def test_sa_public_holidays
    days = Toolkit.sa_public_holidays(2026)
    assert_equal Date.new(2026, 4, 5), Toolkit.easter_sunday(2026)
    assert_includes days, Date.new(2026, 4, 3)   # Good Friday
    assert_includes days, Date.new(2026, 4, 6)   # Family Day
    assert_includes days, Date.new(2026, 8, 10)  # Women's Day falls on a Sunday in 2026
    assert_equal 13, days.size
  end

  def test_working_days_skip_weekend_and_holiday
    # Mon 14 Dec 2026 + 3: Tue 15, (Wed 16 Day of Reconciliation), Thu 17, Fri 18
    assert_match(/→  Fri 18 Dec 2026\z/, run_op(:working_days, "2026-12-14", "days" => "3"))
    assert_match(/→  Thu 17 Dec 2026\z/, run_op(:working_days, "14/12/2026", "days" => "3", "holidays" => "0"))
    assert_match(/→  Fri 06 Nov 2026\z/, run_op(:working_days, "2026-11-09", "days" => "-1"))
  end

  def test_salary
    assert_equal "R 540 000 per year  |  R 45 000 per month  |  R 259.62 per hour", run_op(:salary, "R45 000")
    assert_equal "R 540 000 per year  |  R 45 000 per month  |  R 259.62 per hour", run_op(:salary, "540k", "period" => "annual")
  end

  def test_coded_words
    out = run_op(:coded_words, "A young, competitive leader who is supportive.")
    assert_includes out, "leans masculine-coded (2 masculine-coded, 1 feminine-coded)"
    assert_includes out, "“young” (age)"
  end
end

class RecipeTest < Minitest::Test
  def test_pipeline_stops_at_first_error_and_reports_it
    recipe = Toolkit::Recipe.new
    %w[extract_emails filter sort].each { |id| recipe.add(id) }
    result = recipe.bake("b@example.com a@example.com")
    assert_equal %i[ok error skipped], result.reports.map(&:status)
    assert_equal "b@example.com\na@example.com", result.output
  end

  def test_share_link_round_trip_and_bad_tokens
    recipe = Toolkit::Recipe.new
    recipe.add("xray")
    recipe.steps.first.args["location"] = "Durban"
    copy = Toolkit::Recipe.decode(recipe.encode)
    assert_equal "Durban", copy.steps.first.args["location"]
    assert Toolkit::Recipe.decode("not base64 !!").empty?
    assert Toolkit::Recipe.decode(Base64.urlsafe_encode64('{"a":1}')).empty?
  end
end

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app = Mise::App

  def test_home_and_every_preset_render
    get "/"
    assert last_response.ok?
    assert_includes last_response.body, "Your recipe is empty"
    Mise::PRESETS.each_key do |id|
      get "/", preset: id
      assert last_response.ok?, id
      refute_includes last_response.body, 'class="step error', id
    end
  end

  def test_add_step_then_bake_and_escape_html
    post "/", input: "<script>x</script> a@example.com", do: "add:extract_emails"
    assert_includes last_response.body, "a@example.com</textarea>"
    assert_includes last_response.body, "&lt;script&gt;"
    refute_includes last_response.body, "<script>x"
  end

  def test_unticked_checkbox_and_reordering
    steps = { "0" => { "op" => "extract_emails", "args" => { "lowercase" => "0", "unique" => "1" } },
              "1" => { "op" => "sort", "args" => {} } }
    post "/", input: "B@Example.com", steps: steps, do: "bake"
    assert_includes last_response.body, ">B@Example.com</textarea>"
    post "/", input: "", steps: steps, do: "up:1"
    assert_operator last_response.body.index("Sort lines</h3>"), :<, last_response.body.index("Extract email addresses</h3>")
  end

  def test_download
    post "/", input: "b\na", steps: { "0" => { "op" => "sort" } }, do: "download"
    assert_equal "a\nb", last_response.body
    assert_includes last_response.headers["Content-Disposition"], "attachment"
  end
end
