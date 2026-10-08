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

  describe "locating and searching" do
    let(:kubectl) { instance_double(K8::Kubectl) }
    let(:cluster) { build_stubbed(:cluster) }

    def svc(ns, name, created, ports) = { "metadata" => { "namespace" => ns, "name" => name, "creationTimestamp" => created }, "spec" => { "ports" => ports.map { |p| { "port" => p } } } }

    it "locates the oldest VictoriaLogs service and its 9428 port" do
      items = [ svc("canine-system", "victoria-logs", "2026-10-08T00:00:00Z", [ 9428 ]), svc("logging", "vls-server", "2026-10-05T00:00:00Z", [ 8080, 9428 ]) ]
      allow(kubectl).to receive(:call).with(%w[get services -A -l app.kubernetes.io/name=victoria-logs-single -o json]).and_return({ "items" => items }.to_json)
      expect(described_class.locate(kubectl, cluster)).to eq(described_class::Endpoint.new(namespace: "logging", name: "vls-server", port: 9428))
    end

    it "falls back to the first port" do
      allow(kubectl).to receive(:call).and_return({ "items" => [ svc("logging", "vls", "2026-10-05T00:00:00Z", [ 8080 ]) ] }.to_json)
      expect(described_class.locate(kubectl, cluster).port).to eq(8080)
    end

    it "returns nil when not installed" do
      allow(kubectl).to receive(:call).and_return({ "items" => [] }.to_json)
      expect(described_class.locate(kubectl, cluster)).to be_nil
    end

    it "queries through the service proxy" do
      endpoint = described_class::Endpoint.new(namespace: "logging", name: "vls-server", port: 9428)
      query = described_class.build_query(namespace: "shop", service: "web", range: "6h")
      path = "/api/v1/namespaces/logging/services/vls-server:9428/proxy/select/logsql/query?" + URI.encode_www_form(query: query, limit: 500)
      allow(kubectl).to receive(:call).with([ "get", "--raw", path, "--request-timeout=30s" ]).and_return(%({"_msg":"hi","kubernetes.pod_name":"web-1"}\n))
      rows = described_class.new(kubectl, endpoint).search(namespace: "shop", service: "web", range: "6h")
      expect(rows.map { |r| r[:message] }).to eq([ "hi" ])
    end
  end
end
