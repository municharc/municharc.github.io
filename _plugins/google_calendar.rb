require 'net/http'
require 'json'
require 'uri'
require 'time'

module Jekyll
  class GoogleCalendarGenerator < Generator
    safe true
    priority :high

    def generate(site)
      # Get calendar ID from config, fallback to the one in the iframe
      calendar_id = site.config['google_calendar_id'] || '6d2cecf0ea5c2cdf6809e5847d535f80b430fc71a35ad7ec51c2f13f2b9653990@group.calendar.google.com'
      # Try environment variable first, then config file
      api_key = ENV['GOOGLE_CALENDAR_API_KEY'] || site.config['google_calendar_api_key']
      
      if api_key.nil? || api_key.empty?
        Jekyll.logger.warn "Google Calendar API key not found. Set GOOGLE_CALENDAR_API_KEY environment variable or google_calendar_api_key in _config.yml"
        return
      end

      begin
        events = fetch_upcoming_events(calendar_id, api_key)
        next_event = find_next_event(events)
        
        if next_event
          site.data['next_event'] = format_event(next_event)
          Jekyll.logger.info "Next event updated: #{next_event['summary']}"
        else
          Jekyll.logger.warn "No upcoming events found"
        end
      rescue => e
        Jekyll.logger.error "Error fetching calendar events: #{e.message}"
      end
    end

    private

    def fetch_upcoming_events(calendar_id, api_key)
      # Get events from now until 6 months from now
      time_min = Time.now.iso8601
      time_max = (Time.now + (6 * 30 * 24 * 60 * 60)).iso8601 # 6 months from now
      
      url = URI("https://www.googleapis.com/calendar/v3/calendars/#{calendar_id}/events")
      url.query = URI.encode_www_form({
        key: api_key,
        timeMin: time_min,
        timeMax: time_max,
        singleEvents: true,
        orderBy: 'startTime',
        maxResults: 10
      })

      response = Net::HTTP.get_response(url)
      
      if response.code == '200'
        data = JSON.parse(response.body)
        return data['items'] || []
      else
        raise "API request failed with status #{response.code}: #{response.body}"
      end
    end

    def find_next_event(events)
      now = Time.now
      
      events.find do |event|
        start_time = parse_event_time(event)
        start_time && start_time > now
      end
    end

    def parse_event_time(event)
      start = event['start']
      return nil unless start

      if start['dateTime']
        Time.parse(start['dateTime'])
      elsif start['date']
        # All-day event
        Date.parse(start['date']).to_time
      end
    end

    def format_event(event)
      start_time = parse_event_time(event)
      location = event['location'] || 'TBA'
      
      formatted_event = {
        'title' => event['summary'] || 'Untitled Event',
        'description' => event['description'] || '',
        'location' => location,
        'raw_start_time' => start_time
      }

      if start_time
        # Check if it's an all-day event
        if event['start']['date']
          formatted_event['date'] = start_time.strftime('%d.%m.%Y')
          formatted_event['time'] = 'All day'
        else
          formatted_event['date'] = start_time.strftime('%d.%m.%Y')
          formatted_event['time'] = start_time.strftime('%H:%M')
        end
      else
        formatted_event['date'] = 'TBA'
        formatted_event['time'] = 'TBA'
      end

      formatted_event
    end
  end
end 