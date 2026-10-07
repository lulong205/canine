require 'rails_helper'

RSpec.describe K8::Stateless::Ingress do
  let(:service) { create(:service, allow_public_networking: true) }

  def manifest = YAML.safe_load(described_class.new(service).to_yaml)

  it "renders a wildcard domain as a valid host" do
    create(:domain, service: service, domain_name: "*.example.com")
    expect(manifest.dig("spec", "tls", 0, "hosts")).to eq([ "*.example.com" ])
    expect(manifest.dig("spec", "rules").map { |r| r["host"] }).to eq([ "*.example.com" ])
  end

  it "lists only SSL domains under tls and every domain under rules" do
    create(:domain, service: service, domain_name: "secure.example.com")
    create(:domain, service: service, domain_name: "proxied.example.com", need_ssl: false)
    expect(manifest.dig("spec", "tls", 0, "hosts")).to eq([ "secure.example.com" ])
    expect(manifest.dig("spec", "rules").map { |r| r["host"] }).to eq(%w[secure.example.com proxied.example.com])
    expect(manifest.dig("metadata", "annotations")).to include("cert-manager.io/cluster-issuer" => "letsencrypt")
  end

  it "has no tls and no annotations on Traefik when no domain needs SSL" do
    create(:cluster_package, cluster: service.project.cluster, name: "traefik-ingress")
    create(:domain, service: service, domain_name: "proxied.example.com", need_ssl: false)
    expect(manifest["spec"]).not_to have_key("tls")
    expect(manifest["metadata"]).not_to have_key("annotations")
  end

  it "keeps only the nginx annotation on nginx when no domain needs SSL" do
    create(:domain, service: service, need_ssl: false)
    expect(manifest.dig("metadata", "annotations")).to eq("nginx.ingress.kubernetes.io/proxy-pass-headers" => "*")
  end

  it "has no certificate status when no domain needs SSL" do
    create(:domain, service: service, need_ssl: false)
    expect(described_class.new(service).certificate_status).to be_nil
  end
end
