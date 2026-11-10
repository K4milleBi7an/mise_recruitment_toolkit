# frozen_string_literal: true

require "tzinfo"

module Toolkit
  COMMON_ZONES = %w[
    Africa/Johannesburg Europe/London Europe/Amsterdam Europe/Berlin Asia/Dubai Asia/Kolkata
    Asia/Singapore Asia/Tokyo Australia/Sydney America/New_York America/Chicago America/Los_Angeles UTC
  ].freeze

  def self.zone(id)
    TZInfo::Timezone.get(id.strip)
  rescue TZInfo::InvalidTimezoneIdentifier
    raise Error, "Unknown time zone “#{id.strip}”. Use names like Europe/London or America/New_York."
  end

  # Anonymous Gregorian algorithm.
  def self.easter_sunday(year)
    a = year % 19
    b, c = year.divmod(100)
    d, e = b.divmod(4)
    g = (b - (b + 8) / 25 + 1) / 3
    h = (19 * a + b - d - g + 15) % 30
    i, k = c.divmod(4)
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) / 451
    month, day = (h + l - 7 * m + 114).divmod(31)
    Date.new(year, month, day + 1)
  end

  # Public Holidays Act 36 of 1994: twelve fixed days, and a Sunday holiday moves to Monday.
  # Once-off days the President declares (elections, etc.) are not included.
  def self.sa_public_holidays(year)
    easter = easter_sunday(year)
    days = [[1, 1], [3, 21], [4, 27], [5, 1], [6, 16], [8, 9], [9, 24], [12, 16], [12, 25], [12, 26]]
           .map { |month, day| Date.new(year, month, day) }
    days += [easter - 2, easter + 1] # Good Friday, Family Day
    (days + days.select(&:sunday?).map { |d| d + 1 }).uniq.sort
  end

  def self.working_day?(date, skip_holidays)
    !date.saturday? && !date.sunday? && !(skip_holidays && sa_public_holidays(date.year).include?(date))
  end

  operation :time_zones do
    name "Convert time zones"
    category "Scheduling"
    description "One date and time per line (2026-11-12 14:00). Shows the same moment for panellists elsewhere."
    arg :from, :text, label: "Times are in", default: "Africa/Johannesburg", options: COMMON_ZONES
    arg :to, :text, label: "Show in", default: "Europe/London, America/New_York", options: COMMON_ZONES,
        hint: "Comma separated."
    run do |input, args|
      from = Toolkit.zone(args[:from])
      targets = Util.list(args[:to]).map { |id| Toolkit.zone(id) }
      raise Error, "Add at least one time zone to show." if targets.empty?

      Util.filled_lines(input).map do |line|
        match = line.match(%r{\A(?<date>\S+(?: \w+ \d{4})?)[ T,]+(?<h>\d{1,2})[:h](?<m>\d{2})\z}) or
          raise Error, "Couldn't read “#{line}”. Write it like 2026-11-12 14:00."
        date = Util.parse_date(match[:date])
        begin
          local = from.local_time(date.year, date.month, date.day, match[:h].to_i, match[:m].to_i)
        rescue TZInfo::PeriodNotFound, TZInfo::AmbiguousTime, ArgumentError
          raise Error, "“#{line}” doesn't exist or happens twice in #{from.identifier} (clock change)."
        end
        others = targets.map { |zone| "#{zone.to_local(local).strftime('%a %d %b %H:%M %Z')} (#{zone.identifier})" }
        "#{local.strftime('%a %d %b %Y %H:%M %Z')}  →  #{others.join('  |  ')}"
      end.join("\n")
    end
  end

  operation :slots do
    name "Interview slots"
    category "Scheduling"
    description "Splits a window into slots. Give it candidate names (one per line) to assign them in order, or leave the input empty to list open slots."
    arg :date, :date, label: "Date (optional)", default: ""
    arg :start, :time, label: "From", default: "09:00"
    arg :finish, :time, label: "Until", default: "13:00"
    arg :length, :number, label: "Slot length (min)", default: 45
    arg :gap, :number, label: "Break between (min)", default: 15
    run do |input, args|
      start = Util.parse_clock(args[:start], "From")
      finish = Util.parse_clock(args[:finish], "Until")
      raise Error, "Slot length must be at least 5 minutes." if args[:length] < 5
      raise Error, "The break can't be negative." if args[:gap].negative?

      day = args[:date].strip.empty? ? nil : Util.parse_date(args[:date]).strftime("%a %d %b %Y")
      slots = []
      at = start
      while at + args[:length] <= finish
        slots << [day, "#{Util.clock(at)}–#{Util.clock(at + args[:length])}"].compact.join("  ")
        at += args[:length] + args[:gap]
      end
      raise Error, "No slot fits between #{args[:start]} and #{args[:finish]}." if slots.empty?

      names = Util.filled_lines(input)
      next slots.join("\n") if names.empty?

      rows = names.zip(slots).map { |name, slot| "#{slot || 'NO SLOT LEFT'}  #{name}" }
      spare = slots.drop(names.size).map { |slot| "#{slot}  (open)" }
      (rows + spare).join("\n")
    end
  end

  operation :working_days do
    name "Add working days"
    category "Scheduling"
    description "One date per line. Counts Monday to Friday and skips South African public holidays — handy for offer deadlines and feedback due dates."
    arg :days, :number, label: "Working days to add", default: 5, hint: "Use a minus number to count backwards."
    arg :holidays, :checkbox, label: "Skip SA public holidays", default: true
    run do |input, args|
      raise Error, "Keep it within 2,000 working days." if args[:days].abs > 2000

      Util.filled_lines(input).map do |line|
        date = start = Util.parse_date(line)
        remaining = args[:days].abs
        direction = args[:days].negative? ? -1 : 1
        while remaining.positive?
          date += direction
          remaining -= 1 if Toolkit.working_day?(date, args[:holidays])
        end
        "#{start.strftime('%a %d %b %Y')}  #{args[:days].negative? ? '−' : '+'} #{args[:days].abs} working days  →  #{date.strftime('%a %d %b %Y')}"
      end.join("\n")
    end
  end
end
