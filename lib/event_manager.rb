# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

# Assignment: Clean Phone Numbers
# If we wanted to allow individuals to sign up for mobile alerts
# with the phone numbers, we would need to make sure all of the
# numbers are valid and well-formed
def clean_phone_number(phone_number)
  # Remove non numeric characters if they are present
  phone_number.gsub!(/\D/, '')
  digits = phone_number.length
  return 'Invalid number' if digits < 10 ||
                             digits > 11 ||
                             (digits == 11 && phone_number[0] != 1)

  phone_number[0..9]
end

# Assignment: Time Targeting
# Using the registration date and time we want to find out what
# the peak registration hours are.

# CSV data has the format "month/day/year hour:minute"
# Split the day in 4 ranges of hour and caculate the most active
# range suitable for advertising
# Early 0 - 6am / morning 6am - 12pm / afternnon 12pm - 6pm / night 6pm - 12am
def calculate_peak_registration_hour(data)
  hour_distribution = [{ hours: '00:00 to 06:00', count: 0 },
                       { hours: '06:00 to 12:00', count: 0 },
                       { hours: '12:00 to 18:00', count: 0 },
                       { hours: '18:00 to 24:00', count: 0 }]
  data.each do |row|
    date = DateTime.strptime(row[:regdate], '%m/%d/%y %k:%M')
    case date.hour
    when 0..5
      hour_distribution[0][:count] += 1
    when 6..11
      hour_distribution[1][:count] += 1
    when 12..17
      hour_distribution[2][:count] += 1
    when 18..23
      hour_distribution[3][:count] += 1
    end
  end
  max_range = hour_distribution.max { |a, b| a[:count] <=> b[:count] }
  "Peak registration hours from #{max_range[:hours]}"
end

# Assignment: Day of the Week Targeting
# The big boss gets excited about the results from your hourly
# tabulations. It looks like there are some hours that are clearly
# more important than others. But now, tantalized, she wants to know
# “What days of the week did most people register?”
def calculate_peak_day_of_the_week(data)
  day_distribution = Array.new(7, 0)
  data.each do |row|
    date = DateTime.strptime(row[:regdate], '%m/%d/%y %k:%M')
    # NOTE: wday returns 1-7 starting from monday!
    day_distribution[date.wday - 1] += 1
  end
  days = %w[Monday Tuesday Wednesday Thursday Friday Saturday Sunday]
  peak_day = days[day_distribution.index(day_distribution.max)]
  "Peak registration day is #{peak_day}"
end

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  # phone_number = clean_phone_number(row[:homephone])
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

# Get peak hours and day
contents.rewind
p calculate_peak_day_of_the_week(contents)
contents.rewind
p calculate_peak_registration_hour(contents)
