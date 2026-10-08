require "rails_helper"

RSpec.describe K8::VictoriaLogs do
  describe ".build_query" do
    it "locks to the namespace" do
      expect(described_class.build_query(namespace: "shop")).to eq('_time:1h kubernetes.pod_namespace:="shop" | sort by (_time desc) | limit 500')
    end

    it "adds the service and a quoted, escaped phrase" do
      q = described_class.build_query(namespace: "shop", service: "web", text: 'say "hi" \ ok', range: "15m")
      expect(q).to eq('_time:15m kubernetes.pod_namespace:="shop" kubernetes.pod_labels.app:="web" "say \"hi\" \\\\ ok" | sort by (_time desc) | limit 500')
    end

    it "keeps LogsQL syntax in the search text literal" do
      q = described_class.build_query(namespace: "shop", text: '" OR kubernetes.pod_namespace:="other" | _time:7d')
      expect(q).to start_with('_time:1h kubernetes.pod_namespace:="shop" "\" OR kubernetes.pod_namespace:=\"other\" | _time:7d"')
    end

    it "rejects an unknown range" do
      expect { described_class.build_query(namespace: "shop", range: "30d") }.to raise_error(ArgumentError)
    end
  end

  describe ".parse" do
    it "maps JSON lines to rows and skips blank or broken lines" do
      body = <<~LINES
        {"_time":"2026-10-08T03:00:01.123456789Z","_msg":"GET /up 200","kubernetes.pod_name":"web-7d9f-abc12","kubernetes.pod_labels.app":"web"}

        not json
        {"_time":"2026-10-08T03:00:00Z","_msg":"boot","kubernetes.pod_name":"worker-1"}
      LINES
      rows = described_class.parse(body)
      expect(rows.size).to eq(2)
      expect(rows.first).to include(pod: "web-7d9f-abc12", service: "web", message: "GET /up 200")
      expect(rows.first[:time].strftime("%Y-%m-%d %H:%M:%S.%L")).to eq("2026-10-08 03:00:01.123")
      expect(rows.last).to include(service: nil, message: "boot")
    end
  end
end
