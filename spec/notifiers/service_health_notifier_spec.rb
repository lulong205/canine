require "rails_helper"

RSpec.describe ServiceHealthNotifier do
  it "sets event to health in the webhook payload" do
    service = create(:service)
    expect(ServiceHealthNotifier.with(project: service.project, service: service, status_change: :down).build_payload("webhook")[:event]).to eq("health")
  end
end
