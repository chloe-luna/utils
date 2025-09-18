#!/usr/bin/env ruby

require 'webrick'
require 'json'
require 'time'
require 'logger'
require 'fileutils'

class NeutrinoDetectionServer
  attr_reader :detections, :server_start_time, :data_file

  def initialize(options = {})
    @port = options[:port] || 3000
    @host = options[:host] || 'localhost'
    @data_file = options[:data_file] || 'neutrino_detections.json'
    @save_interval = options[:save_interval] || 30 # seconds
    
    @detections = []
    @server_start_time = Time.now
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
    
    # Load existing data if available
    load_data
    
    # Set up periodic saving
    setup_periodic_save
    
    # Set up web server
    @server = WEBrick::HTTPServer.new(
      Port: @port,
      Host: @host,
      Logger: WEBrick::Log.new('/dev/null'),
      AccessLog: []
    )
    
    setup_routes
  end

  def start
    @logger.info "Starting Neutrino Detection Server on #{@host}:#{@port}"
    @logger.info "Data file: #{@data_file}"
    @logger.info "Periodic save interval: #{@save_interval} seconds"
    
    # Handle graceful shutdown
    trap('INT') do
      @logger.info "Shutting down server..."
      save_data
      @server.shutdown
    end
    
    @server.start
  end

  private

  def setup_routes
    # Endpoint to receive detection events
    @server.mount_proc '/neutrino_detected' do |req, res|
      handle_detection(req, res)
    end
    
    # Summary dashboard
    @server.mount_proc '/' do |req, res|
      handle_dashboard(req, res)
    end
    
    # API endpoint for raw data
    @server.mount_proc '/api/detections' do |req, res|
      handle_api_detections(req, res)
    end
    
    # API endpoint for statistics
    @server.mount_proc '/api/stats' do |req, res|
      handle_api_stats(req, res)
    end
  end

  def handle_detection(req, res)
    if req.request_method == 'POST'
      begin
        body = req.body
        detection_data = JSON.parse(body)
        
        # Add server timestamp and ID
        detection = {
          'id' => generate_id,
          'received_at' => Time.now.iso8601,
          'source' => detection_data['source'],
          'timestamp' => detection_data['timestamp'],
          'type' => detection_data['type'],
          'details' => detection_data['details'],
          'raw_data' => detection_data
        }
        
        @detections << detection
        @logger.info "Received detection from #{detection['source']}: #{detection['type']}"
        
        res.status = 200
        res['Content-Type'] = 'application/json'
        res.body = JSON.pretty_generate({
          'status' => 'success',
          'message' => 'Detection recorded',
          'detection_id' => detection['id'],
          'total_detections' => @detections.length
        })
        
      rescue JSON::ParserError => e
        res.status = 400
        res['Content-Type'] = 'application/json'
        res.body = JSON.pretty_generate({
          'status' => 'error',
          'message' => 'Invalid JSON format'
        })
      rescue => e
        @logger.error "Error processing detection: #{e.message}"
        res.status = 500
        res['Content-Type'] = 'application/json'
        res.body = JSON.pretty_generate({
          'status' => 'error',
          'message' => 'Internal server error'
        })
      end
    else
      res.status = 405
      res.body = 'Method not allowed'
    end
  end

  def handle_dashboard(req, res)
    stats = generate_statistics
    
    html = generate_dashboard_html(stats)
    
    res.status = 200
    res['Content-Type'] = 'text/html'
    res.body = html
  end

  def handle_api_detections(req, res)
    limit = req.query['limit']&.to_i || 100
    offset = req.query['offset']&.to_i || 0
    source_filter = req.query['source']
    
    filtered_detections = @detections
    
    if source_filter
      filtered_detections = filtered_detections.select { |d| d['source']&.downcase&.include?(source_filter.downcase) }
    end
    
    paginated_detections = filtered_detections.reverse[offset, limit] || []
    
    res.status = 200
    res['Content-Type'] = 'application/json'
    res.body = JSON.pretty_generate({
      'detections' => paginated_detections,
      'total_count' => filtered_detections.length,
      'offset' => offset,
      'limit' => limit
    })
  end

  def handle_api_stats(req, res)
    stats = generate_statistics
    
    res.status = 200
    res['Content-Type'] = 'application/json'
    res.body = JSON.pretty_generate(stats)
  end

  def generate_statistics
    now = Time.now
    uptime_seconds = (now - @server_start_time).to_i
    
    # Basic counts
    total_detections = @detections.length
    
    # Source breakdown
    sources = @detections.group_by { |d| d['source'] }
    source_counts = sources.transform_values(&:length)
    
    # Type breakdown
    types = @detections.group_by { |d| d['type'] }
    type_counts = types.transform_values(&:length)
    
    # Time-based analysis
    recent_detections = @detections.select { |d| Time.parse(d['received_at']) > (now - 3600) } # Last hour
    
    # Rate calculations
    detections_per_hour = total_detections.to_f / (uptime_seconds / 3600.0)
    
    {
      'server_uptime_seconds' => uptime_seconds,
      'server_start_time' => @server_start_time.iso8601,
      'total_detections' => total_detections,
      'detections_last_hour' => recent_detections.length,
      'average_detections_per_hour' => detections_per_hour.round(2),
      'sources' => source_counts,
      'detection_types' => type_counts,
      'latest_detection' => @detections.last,
      'data_file_size_bytes' => File.exist?(@data_file) ? File.size(@data_file) : 0
    }
  end

  def generate_dashboard_html(stats)
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
          <title>Neutrino Detection Dashboard</title>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
              body { 
                  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; 
                  margin: 0; padding: 20px; background: #f5f5f5; 
              }
              .container { max-width: 1200px; margin: 0 auto; }
              .header { background: #2c3e50; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
              .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
              .stat-card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
              .stat-number { font-size: 2em; font-weight: bold; color: #3498db; }
              .stat-label { color: #7f8c8d; margin-bottom: 10px; }
              .recent-detections { margin-top: 20px; }
              .detection-item { 
                  background: white; margin: 10px 0; padding: 15px; border-radius: 8px; 
                  border-left: 4px solid #e74c3c; box-shadow: 0 2px 4px rgba(0,0,0,0.1);
              }
              .detection-source { font-weight: bold; color: #2c3e50; }
              .detection-time { color: #7f8c8d; font-size: 0.9em; }
              .detection-type { color: #e74c3c; margin: 5px 0; }
              .refresh-note { text-align: center; margin: 20px 0; color: #7f8c8d; }
              table { width: 100%; border-collapse: collapse; }
              th, td { padding: 8px 12px; text-align: left; border-bottom: 1px solid #ddd; }
              th { background: #f8f9fa; }
          </style>
          <script>
              // Auto-refresh every 30 seconds
              setTimeout(() => location.reload(), 30000);
          </script>
      </head>
      <body>
          <div class="container">
              <div class="header">
                  <h1>🌌 Neutrino Detection Dashboard</h1>
                  <p>Server started: #{stats['server_start_time']} | Uptime: #{format_duration(stats['server_uptime_seconds'])}</p>
              </div>
              
              <div class="stats-grid">
                  <div class="stat-card">
                      <div class="stat-label">Total Detections</div>
                      <div class="stat-number">#{stats['total_detections']}</div>
                  </div>
                  
                  <div class="stat-card">
                      <div class="stat-label">Detections (Last Hour)</div>
                      <div class="stat-number">#{stats['detections_last_hour']}</div>
                  </div>
                  
                  <div class="stat-card">
                      <div class="stat-label">Average per Hour</div>
                      <div class="stat-number">#{stats['average_detections_per_hour']}</div>
                  </div>
                  
                  <div class="stat-card">
                      <div class="stat-label">Data File Size</div>
                      <div class="stat-number">#{format_bytes(stats['data_file_size_bytes'])}</div>
                  </div>
              </div>
              
              #{generate_sources_table(stats['sources'])}
              #{generate_types_table(stats['detection_types'])}
              #{generate_recent_detections_html}
              
              <div class="refresh-note">
                  🔄 Page auto-refreshes every 30 seconds | 
                  <a href="/api/detections">API: All Detections</a> | 
                  <a href="/api/stats">API: Statistics</a>
              </div>
          </div>
      </body>
      </html>
    HTML
  end

  def generate_sources_table(sources)
    return '' if sources.empty?
    
    rows = sources.map do |source, count|
      "<tr><td>#{source}</td><td>#{count}</td></tr>"
    end.join
    
    <<~HTML
      <div class="stat-card" style="grid-column: 1 / -1; margin-top: 20px;">
          <h3>Detection Sources</h3>
          <table>
              <thead><tr><th>Source</th><th>Detections</th></tr></thead>
              <tbody>#{rows}</tbody>
          </table>
      </div>
    HTML
  end

  def generate_types_table(types)
    return '' if types.empty?
    
    rows = types.map do |type, count|
      "<tr><td>#{type}</td><td>#{count}</td></tr>"
    end.join
    
    <<~HTML
      <div class="stat-card" style="grid-column: 1 / -1;">
          <h3>Detection Types</h3>
          <table>
              <thead><tr><th>Type</th><th>Count</th></tr></thead>
              <tbody>#{rows}</tbody>
          </table>
      </div>
    HTML
  end

  def generate_recent_detections_html
    recent = @detections.last(10).reverse
    return '<div class="stat-card" style="grid-column: 1 / -1;"><h3>Recent Detections</h3><p>No detections yet.</p></div>' if recent.empty?
    
    items = recent.map do |detection|
      <<~HTML
        <div class="detection-item">
            <div class="detection-source">#{detection['source']}</div>
            <div class="detection-type">#{detection['type']}</div>
            <div class="detection-time">#{detection['received_at']}</div>
            <div>#{detection['details']}</div>
        </div>
      HTML
    end.join
    
    <<~HTML
      <div class="recent-detections" style="grid-column: 1 / -1;">
          <div class="stat-card">
              <h3>Recent Detections (Last 10)</h3>
              #{items}
          </div>
      </div>
    HTML
  end

  def format_duration(seconds)
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    secs = seconds % 60
    "#{hours}h #{minutes}m #{secs}s"
  end

  def format_bytes(bytes)
    units = %w[B KB MB GB]
    size = bytes.to_f
    unit_index = 0
    
    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end
    
    "#{size.round(1)} #{units[unit_index]}"
  end

  def setup_periodic_save
    Thread.new do
      loop do
        sleep @save_interval
        save_data
      end
    end
  end

  def save_data
    begin
      data = {
        'server_start_time' => @server_start_time.iso8601,
        'last_saved' => Time.now.iso8601,
        'detections' => @detections
      }
      
      File.write(@data_file, JSON.pretty_generate(data))
      @logger.debug "Data saved to #{@data_file} (#{@detections.length} detections)"
    rescue => e
      @logger.error "Failed to save data: #{e.message}"
    end
  end

  def load_data
    return unless File.exist?(@data_file)
    
    begin
      data = JSON.parse(File.read(@data_file))
      @detections = data['detections'] || []
      
      if data['server_start_time']
        # Keep original server start time if restarting
        @server_start_time = Time.parse(data['server_start_time'])
      end
      
      @logger.info "Loaded #{@detections.length} detections from #{@data_file}"
    rescue => e
      @logger.error "Failed to load data: #{e.message}"
    end
  end

  def generate_id
    "#{Time.now.to_i}-#{rand(10000)}"
  end
end

# Start the server
if __FILE__ == $0
  options = {
    port: (ENV['PORT'] || 3000).to_i,
    host: ENV['HOST'] || 'localhost',
    data_file: ENV['DATA_FILE'] || 'neutrino_detections.json',
    save_interval: (ENV['SAVE_INTERVAL'] || 30).to_i
  }
  
  server = NeutrinoDetectionServer.new(options)
  server.start
end

# Example usage:
#
# 1. Start with defaults:
#    ruby neutrino_server.rb
#
# 2. Custom port and host:
#    PORT=8080 HOST=0.0.0.0 ruby neutrino_server.rb
#
# 3. Custom data file and save interval:
#    DATA_FILE=my_detections.json SAVE_INTERVAL=60 ruby neutrino_server.rb
#
# 4. Test the webhook endpoint:
#    curl -X POST http://localhost:3000/neutrino_detected \
#         -H "Content-Type: application/json" \
#         -d '{"source":"Test Source","timestamp":"2025-09-18T10:30:45Z","type":"Test Detection","details":"This is a test"}'
