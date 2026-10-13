require "rails_helper"

RSpec.describe Projects::DeploymentsController, type: :request do
  include Devise::Test::IntegrationHelpers

  let(:project) { create(:project) }
  let(:build) { create(:build, project: project, status: :in_progress) }

  before do
    sign_in project.account.owner
    allow(BuildNotifier).to receive(:with).and_call_original
    allow(DeploymentNotifier).to receive(:with).and_call_original
  end

  describe "GET #index" do
    let!(:web) { create(:service, project: project) }

    it "renders the content area without the container cap" do
      get project_deployments_path(project)
      expect(Nokogiri::HTML(response.body).at_css(".content-wrapper")["class"].split).not_to include("container")
    end

    it "renders Restart as a red outline button" do
      get project_deployments_path(project)
      expect(Nokogiri::HTML(response.body).at_css("form[action$='/restart'] button")["class"].split).to include("btn-outline", "btn-error")
    end
  end

  describe "PATCH #kill" do
    it "kills the build and sends one cancelled notification" do
      patch kill_project_deployment_path(project, build)
      expect(response).to redirect_to(project_deployment_path(project, build))
      expect(build.reload).to be_killed
      expect(BuildNotifier).to have_received(:with).with(project: project, build: build).once
    end

    it "sends nothing when the build is not in progress" do
      build.failed!
      patch kill_project_deployment_path(project, build)
      expect(build.reload).to be_failed
      expect(BuildNotifier).not_to have_received(:with)
    end
  end

  describe "PATCH #kill_deploy" do
    let!(:deployment) { create(:deployment, build: build, status: :in_progress) }

    it "kills the deployment and sends one cancelled notification" do
      patch kill_deploy_project_deployment_path(project, build)
      expect(response).to redirect_to(project_deployment_path(project, build))
      expect(deployment.reload).to be_killed
      expect(DeploymentNotifier).to have_received(:with).with(project: project, deployment: deployment).once
    end
  end
end
