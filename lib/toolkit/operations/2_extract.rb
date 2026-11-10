# frozen_string_literal: true

module Toolkit
  EMAIL = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i
  URL = %r{(?:https?://|www\.)[^\s<>"')\]]+}i
  # +27 82 123 4567, 0027821234567, +27 (0)82 123 4567, 082-123-4567, (021) 555 1234
  SA_PHONE = /(?<![\d+])(?:(?:\+|00)?27[\s\-.]?(?:\(0\)[\s\-.]?)?|\(?0)\(?\d{2}\)?[\s\-.]?\d{3}[\s\-.]?\d{4}(?!\d)/
  SA_ID = /(?<!\d)\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01])\d{7}(?!\d)/

  def self.sa_phone_digits(raw) = raw.gsub(/\D/, "")[-9..]

  operation :extract_emails do
    name "Extract email addresses"
    category "Extract"
    description "Pulls every email address out of messy text, one per line."
    arg :lowercase, :checkbox, label: "Lowercase", default: true
    arg :unique, :checkbox, label: "Remove duplicates", default: true
    run do |input, args|
      found = input.scan(EMAIL).map { |e| e.sub(/\.+\z/, "") }
      found.map!(&:downcase) if args[:lowercase]
      (args[:unique] ? found.uniq : found).join("\n")
    end
  end

  operation :extract_phones do
    name "Extract SA phone numbers"
    category "Extract"
    description "Finds South African numbers in any format and rewrites them consistently."
    arg :format, :select, label: "Write as", default: "e164",
        options: [["e164", "+27821234567"], ["spaced", "+27 82 123 4567"], ["local", "082 123 4567"]]
    arg :unique, :checkbox, label: "Remove duplicates", default: true
    run do |input, args|
      found = input.scan(SA_PHONE).map do |raw|
        d = Toolkit.sa_phone_digits(raw)
        case args[:format]
        when "spaced" then "+27 #{d[0, 2]} #{d[2, 3]} #{d[5, 4]}"
        when "local" then "0#{d[0, 2]} #{d[2, 3]} #{d[5, 4]}"
        else "+27#{d}"
        end
      end
      (args[:unique] ? found.uniq : found).join("\n")
    end
  end

  operation :extract_urls do
    name "Extract links"
    category "Extract"
    description "Pulls every web link out of the text, one per line."
    arg :unique, :checkbox, label: "Remove duplicates", default: true
    run do |input, args|
      found = input.scan(URL).map { |u| u.sub(/[.,;:!?]+\z/, "") }
      (args[:unique] ? found.uniq : found).join("\n")
    end
  end

  operation :redact do
    name "Redact personal details"
    category "Privacy"
    description "Masks contact details and ID numbers before you share a CV or notes. Names are not detected — check those yourself."
    arg :emails, :checkbox, label: "Email addresses", default: true
    arg :phones, :checkbox, label: "Phone numbers", default: true
    arg :ids, :checkbox, label: "SA ID numbers", default: true
    arg :urls, :checkbox, label: "Links (LinkedIn, portfolios)", default: true
    run do |input, args|
      text = input.dup
      text.gsub!(SA_ID, "[ID NUMBER REMOVED]") if args[:ids]
      text.gsub!(URL, "[LINK REMOVED]") if args[:urls]
      text.gsub!(EMAIL, "[EMAIL REMOVED]") if args[:emails]
      text.gsub!(SA_PHONE, "[PHONE REMOVED]") if args[:phones]
      text
    end
  end
end
