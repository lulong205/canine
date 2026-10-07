require 'rails_helper'

RSpec.describe Deployments::LegacyDeploymentService, "waiting for rollouts" do
  let(:project) { create(:project) }
  let(:deployment) { create(:deployment, build: create(:build, project: project)) }
  let(:kubectl_calls) { [] }
  let(:on_rollout) { nil }

  let!(:web) { create(:service, project: project, name: 'web') }
  let!(:worker) { create(:service, :background_service, project: project, name: 'worker') }
  let!(:scheduler) { create(:service, :cron_job, project: project, name: 'scheduler') }

  def deploy = described_class.new(deployment, project.account.owner).deploy

  before do
    allow_any_instance_of(K8::Kubectl).to receive(:apply_yaml)
    allow_any_instance_of(K8::Kubectl).to receive(:call) do |_kubectl, command|
      kubectl_calls << command
      on_rollout&.call if command[2..3] == %w[rollout status]
      "items: []"
    end
    allow(Providers::GenerateConfigJson).to receive(:execute).and_return(
      double(failure?: false, docker_config_json: '{}')
    )
    allow(DeploymentNotifier).to receive(:with).and_call_original
  end

  it "waits for every web and background Deployment, not cron jobs" do
    deploy
    targets = kubectl_calls.select { |c| c[2..3] == %w[rollout status] }.map { |c| c[4] }
    expect(targets).to match_array(%w[deployment/web deployment/worker])
    expect(kubectl_calls).to include([ "-n", project.namespace, "rollout", "status", "deployment/web", "--timeout=30m" ])
    expect(deployment.reload).to be_completed
  end

  context "when a rollout fails" do
    let(:on_rollout) { -> { raise StandardError, 'deployment "web" exceeded its progress deadline' } }

    it "marks the deployment failed and notifies once" do
      deploy
      expect(deployment.reload).to be_failed
      expect(DeploymentNotifier).to have_received(:with).once
    end
  end

  context "when the deployment is killed during the wait" do
    let(:on_rollout) do
      -> {
        Deployment.where(id: deployment.id).update_all(status: Deployment.statuses[:killed])
        raise StandardError, "killed"
      }
    end

    it "keeps it killed and sends nothing" do
      deploy
      expect(deployment.reload).to be_killed
      expect(DeploymentNotifier).not_to have_received(:with)
    end
  end
end
