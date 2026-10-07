require "rails_helper"

RSpec.describe DeploymentNotifier do
  it "sets event to deployment in the webhook payload" do
    deployment = create(:deployment)
    expect(DeploymentNotifier.with(project: deployment.project, deployment: deployment).build_payload("webhook")[:event]).to eq("deployment")
  end

  it "reports a killed deployment as cancelled" do
    deployment = create(:deployment, status: :killed, build: create(:build, commit_message: "fix pay later"))
    payload = DeploymentNotifier.with(project: deployment.project, deployment: deployment).build_payload("webhook")
    expect(payload).to include(status: "failed", status_text: "Cancelled", emoji: "🚫", message: "Deploy cancelled for v1.0.0: \"fix pay later\"")
  end
end
