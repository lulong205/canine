require "rails_helper"

RSpec.describe BuildNotifier do
  it "sets event to build in the webhook payload" do
    build_record = create(:build)
    expect(BuildNotifier.with(project: build_record.project, build: build_record).build_payload("webhook")[:event]).to eq("build")
  end

  it "reports a killed build as cancelled" do
    build_record = create(:build, status: :killed, commit_message: "fix pay later")
    payload = BuildNotifier.with(project: build_record.project, build: build_record).build_payload("webhook")
    expect(payload).to include(status: "failed", status_text: "Cancelled", emoji: "🚫", message: "Build cancelled for \"fix pay later\"")
  end
end
