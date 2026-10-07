require "rails_helper"

RSpec.describe TestNotifier do
  it "sets event to test in the webhook payload" do
    notifier = create(:notifier, :webhook)
    expect(TestNotifier.new(project: notifier.project, notifier: notifier).build_payload("webhook")[:event]).to eq("test")
  end
end
