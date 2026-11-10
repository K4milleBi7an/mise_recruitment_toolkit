# Mise

A CyberChef-style toolkit for recruitment coordinators, sourcers and TA interns.
Pick operations, stack them into a recipe, paste your text, bake.

**Stack:** Ruby (Sinatra) + ERB-rendered HTML + one plain CSS file. No database, no build step.
The only JavaScript is a ten-line "Copy output" button; everything else works with scripts off.

## Run it

Requires Ruby 3.2 or newer.

    bundle install
    bundle exec rackup          # then open http://localhost:9292

Run the tests:

    bundle exec ruby test/toolkit_test.rb

## How it works

The whole page is one HTML form. Every button (add a step, move it, bake) posts the form;
Ruby rebuilds the recipe from the fields, runs it and renders the page again.
There are no sessions and nothing is saved between requests.

| File | What it does |
| --- | --- |
| `app.rb` | Two routes: `GET /` and `POST /` |
| `lib/toolkit.rb` | The engine: operation DSL, `Recipe`, shared helpers. No HTTP in here |
| `lib/toolkit/operations/*.rb` | The operations, grouped by category |
| `lib/presets.rb` | Starter recipes with fictional sample input |
| `views/` | `layout.erb` and `index.erb` (auto-escaped) |
| `public/style.css` | All styling, light and dark |

## Add an operation

Drop a block into any file under `lib/toolkit/operations/`. It appears in the sidebar on restart.

    Toolkit.operation :reverse_lines do
      name "Reverse line order"
      category "Tidy"
      description "Last line first."
      arg :keep_blank, :checkbox, label: "Keep blank lines", default: false
      run do |input, args|
        rows = Toolkit::Util.lines(input)
        rows = rows.reject(&:empty?) unless args[:keep_blank]
        rows.reverse.join("\n")
      end
    end

Argument types: `:text`, `:textarea`, `:number`, `:checkbox`, `:select`, `:date`, `:time`.
Raise `Toolkit::Error, "message"` to show the user a friendly error on that step.

## Privacy notes (POPIA)

- Pasted text is processed in memory for one request and never written to disk.
- Input travels in the POST body only, so it stays out of URLs, browser history and access logs.
- "Link to this recipe" encodes the steps and their settings, never the input. Settings you type
  (for example a mail-merge template) are in the link, so keep personal details out of those.
- If you host it for a team, put it behind HTTPS.

## Known limits

- Phone and ID detection is South African formats only.
- "Redact personal details" does not detect names or addresses.
- Public holidays cover the twelve statutory days plus the Sunday-to-Monday rule, not once-off declared days.
- Salary conversion is gross arithmetic only: no PAYE, UIF or benefits.
- Coded-wording lists are a prompt to reread a job ad, not a verdict on it.
