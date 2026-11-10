# frozen_string_literal: true

module Toolkit
  def self.column_key(header) = header.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_|_\z/, "")

  operation :csv_column do
    name "Pick a CSV column"
    category "Spreadsheets"
    description "Pulls one column out of pasted CSV or Excel cells."
    arg :column, :text, label: "Column name or number", default: "1", placeholder: "Email"
    run do |input, args|
      table = Util.table(input)
      wanted = args[:column].strip
      header =
        if wanted.match?(/\A\d+\z/) then table.headers[wanted.to_i - 1]
        else table.headers.find { |h| Toolkit.column_key(h) == Toolkit.column_key(wanted) }
        end
      raise Error, "No column “#{wanted}”. Found: #{table.headers.compact.join(', ')}." unless header

      table.map { |row| row[header].to_s.strip }.join("\n")
    end
  end

  operation :csv_to_markdown do
    name "CSV to Markdown table"
    category "Spreadsheets"
    description "Makes a table you can paste into Notion, Slack canvases or GitHub."
    run do |input, _|
      table = Util.table(input)
      cell = ->(value) { value.to_s.strip.gsub("|", "\\|").gsub(/\s*\n\s*/, " ") }
      rows = [table.headers, table.headers.map { "---" }] + table.map(&:fields)
      rows.map { |row| "| #{row.map(&cell).join(' | ')} |" }.join("\n")
    end
  end

  operation :mail_merge do
    name "Mail merge"
    category "Spreadsheets"
    description "One message per CSV row. Write {{column_name}} where each value should go."
    arg :template, :textarea, label: "Message template",
        default: "Hi {{first_name}},\n\nYour interview for the {{role}} role is confirmed for {{date}} at {{time}}.\n\nKind regards,\nTalent team",
        hint: "Column names become lower_case_with_underscores."
    arg :divider, :text, label: "Divider between messages", default: "----------"
    run do |input, args|
      table = Util.table(input)
      keys = table.headers.to_h { |h| [Toolkit.column_key(h), h] }
      wanted = args[:template].scan(/\{\{\s*([^}]+?)\s*\}\}/).flatten.map { |k| Toolkit.column_key(k) }.uniq
      missing = wanted - keys.keys
      unless missing.empty?
        raise Error, "No column for {{#{missing.join('}}, {{')}}}. Available: #{keys.keys.map { |k| "{{#{k}}}" }.join(' ')}"
      end

      table.map do |row|
        args[:template].gsub(/\{\{\s*([^}]+?)\s*\}\}/) { row[keys[Toolkit.column_key(Regexp.last_match(1))]].to_s.strip }
      end.join("\n#{args[:divider]}\n")
    end
  end
end
