# Reads a project's pod logs from VictoriaLogs (installed by the victoria-logs package or by hand).
class K8::VictoriaLogs
  RANGES = %w[15m 1h 6h 24h 7d].freeze
  LIMIT = 500

  # The namespace filter is always added here, and user text is only ever a quoted phrase,
  # so a search can't reach another project's logs.
  def self.build_query(namespace:, service: nil, text: nil, range: "1h", limit: LIMIT)
    raise ArgumentError, "unknown range: #{range}" unless RANGES.include?(range)

    filters = [ "_time:#{range}", "kubernetes.pod_namespace:=#{quote(namespace)}" ]
    filters << "kubernetes.pod_labels.app:=#{quote(service)}" if service.present?
    filters << quote(text) if text.present?
    "#{filters.join(" ")} | sort by (_time desc) | limit #{limit}"
  end

  # VictoriaLogs answers with one JSON object per line.
  def self.parse(body)
    body.to_s.each_line.filter_map do |line|
      next if line.strip.empty?

      entry = JSON.parse(line)
      {
        time: (Time.iso8601(entry["_time"]).utc rescue nil),
        pod: entry["kubernetes.pod_name"],
        service: entry["kubernetes.pod_labels.app"],
        message: entry["_msg"].to_s
      }
    rescue JSON::ParserError
      nil
    end
  end

  def self.quote(value)
    %("#{value.to_s.gsub(/["\\]/) { |c| "\\#{c}" }}")
  end
  private_class_method :quote
end
