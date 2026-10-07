require 'rails_helper'

RSpec.describe K8::AddOns::Ingress do
  it "renders a wildcard domain as a valid host" do
    endpoint = double(metadata: double(name: "redis-master"))
    yaml = described_class.new(create(:add_on), endpoint, 6379, [ "*.example.com" ]).to_yaml
    expect(YAML.safe_load(yaml).dig("spec", "rules", 0, "host")).to eq("*.example.com")
  end
end
