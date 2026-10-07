require "rails_helper"

RSpec.describe BuildNotifier do
  it "sets event to build in the webhook payload" do
    build_record = create(:build)
    expect(BuildNotifier.with(project: build_record.project, build: build_record).build_payload("webhook")[:event]).to eq("build")
  end
end
