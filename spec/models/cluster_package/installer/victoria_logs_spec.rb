require "rails_helper"

RSpec.describe ClusterPackage::Installer::VictoriaLogs do
  let(:helm) { instance_double(K8::Helm::Client, add_repo: nil, repo_update: nil, install: nil, uninstall: nil) }
  let(:kubectl) { instance_double(K8::Kubectl, connection: double, runner: double) }
  let(:config) { { "retention_days" => "60", "max_disk_gib" => "20" } }
  let(:package) { build(:cluster_package, name: "victoria-logs", config: config) }
  let(:single_values) do
    { "server" => { "fullnameOverride" => "victoria-logs", "retentionPeriod" => "60d", "retentionDiskSpaceUsage" => "20GiB",
                    "persistentVolume" => { "enabled" => true, "size" => "25Gi" } } }
  end
  let(:collector_values) { { "remoteWrite" => [ { "url" => "http://victoria-logs.canine-system.svc:9428" } ] } }

  before { allow(K8::Helm::Client).to receive(:connect).and_return(helm) }

  it "installs VictoriaLogs and the collector at the pinned versions" do
    described_class.new(package).install!(kubectl)
    expect(helm).to have_received(:install).with("victoria-logs-single", "vm/victoria-logs-single", "0.13.10",
      values: single_values, namespace: "canine-system", create_namespace: true).ordered
    expect(helm).to have_received(:install).with("victoria-logs-collector", "vm/victoria-logs-collector", "0.3.8",
      values: collector_values, namespace: "canine-system", create_namespace: true).ordered
    expect(helm).to have_received(:add_repo).with("vm", "https://victoriametrics.github.io/helm-charts")
  end

  [ nil, {}, { "retention_days" => "", "max_disk_gib" => "abc" }, { "retention_days" => "0", "max_disk_gib" => "-5" } ].each do |cfg|
    it "falls back to 60 days / 20 GiB for config #{cfg.inspect}" do
      package.config = cfg
      described_class.new(package).install!(kubectl)
      expect(helm).to have_received(:install).with("victoria-logs-single", anything, anything, hash_including(values: single_values))
    end
  end

  it "uses configured values" do
    package.config = { "retention_days" => "14", "max_disk_gib" => "50" }
    described_class.new(package).install!(kubectl)
    expected = single_values.deep_merge("server" => { "retentionPeriod" => "14d", "retentionDiskSpaceUsage" => "50GiB", "persistentVolume" => { "size" => "55Gi" } })
    expect(helm).to have_received(:install).with("victoria-logs-single", anything, anything, hash_including(values: expected))
  end

  it "uninstalls the collector first, then VictoriaLogs" do
    described_class.new(package).uninstall!(kubectl)
    expect(helm).to have_received(:uninstall).with("victoria-logs-collector", namespace: "canine-system").ordered
    expect(helm).to have_received(:uninstall).with("victoria-logs-single", namespace: "canine-system").ordered
  end
end
