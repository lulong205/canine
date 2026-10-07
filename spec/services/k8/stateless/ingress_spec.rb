require 'rails_helper'

RSpec.describe K8::Stateless::Ingress do
  let(:service) { create(:service, allow_public_networking: true) }

  def manifest = YAML.safe_load(described_class.new(service).to_yaml)

  it "renders a wildcard domain as a valid host" do
    create(:domain, service: service, domain_name: "*.example.com")
    expect(manifest.dig("spec", "tls", 0, "hosts")).to eq([ "*.example.com" ])
    expect(manifest.dig("spec", "rules").map { |r| r["host"] }).to eq([ "*.example.com" ])
  end
end
