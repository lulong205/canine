require "rails_helper"

RSpec.describe DeploymentNotifier do
  it "sets event to deployment in the webhook payload" do
    deployment = create(:deployment)
    expect(DeploymentNotifier.with(project: deployment.project, deployment: deployment).build_payload("webhook")[:event]).to eq("deployment")
  end
end
