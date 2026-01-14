require 'net/http'
require 'json'
require 'uri'
require 'time'

module Jekyll
  class GoogleCalendarGenerator < Generator
    safe true
    priority :high

    def generate(site)
      # Get calendar ID from config, fallback to the original
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
          Jekyll.logger.warn "No upcoming events found. Falling back to most recent past event."

          past_events = fetch_past_events(calendar_id, api_key)
          last_event = find_most_recent_past_event(past_events)

          if last_event
            site.data['next_event'] = format_event(last_event)
            Jekyll.logger.info "Showing most recent past event: #{last_event['summary']}"
          else
            Jekyll.logger.warn "No past events found in the lookback window"
          end
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

    def fetch_past_events(calendar_id, api_key)
      # Look back up to 12 months for past events
      time_min = (Time.now - (12 * 30 * 24 * 60 * 60)).iso8601 # ~12 months ago
      time_max = Time.now.iso8601

      url = URI("https://www.googleapis.com/calendar/v3/calendars/#{calendar_id}/events")
      url.query = URI.encode_www_form({
        key: api_key,
        timeMin: time_min,
        timeMax: time_max,
        singleEvents: true,
        orderBy: 'startTime',
        maxResults: 250
      })

      response = Net::HTTP.get_response(url)

      if response.code == '200'
        data = JSON.parse(response.body)
        return data['items'] || []
      else
        raise "API request failed with status #{response.code}: #{response.body}"
      end
    end

    def find_most_recent_past_event(events)
      now = Time.now
      past_events = events.map { |e| [e, parse_event_time(e)] }
                          .select { |(_, t)| t && t <= now }
      return nil if past_events.empty?

      past_events.max_by { |(_, t)| t }.first
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