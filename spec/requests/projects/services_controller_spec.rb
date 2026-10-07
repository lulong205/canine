require "rails_helper"

RSpec.describe Projects::ServicesController, type: :request do
  include Devise::Test::IntegrationHelpers

  let(:project) { create(:project) }

  before do
    sign_in project.account.owner
  end

  describe "PUT #update" do
    it "saves probe YAML" do
      service = create(:service, project: project)
      put project_service_path(project, service), params: { service: { probes_yaml: "livenessProbe:\n  periodSeconds: 30\n" } }
      expect(response).to redirect_to(project_services_path(project))
      expect(service.reload.probes_yaml).to eq("livenessProbe" => { "periodSeconds" => 30 })
    end

    it "shows the error for invalid YAML and saves nothing" do
      service = create(:service, project: project)
      put project_service_path(project, service), params: { service: { probes_yaml: "livenessProbe: [" } }
      expect(response).to redirect_to(project_services_path(project))
      expect(flash[:alert]).to eq("Service could not be updated: Probes yaml is not valid YAML")
      expect(service.reload.probes_yaml).to be_nil
    end
  end
end
