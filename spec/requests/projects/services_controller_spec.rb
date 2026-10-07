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

    it "shows the error for YAML with aliases instead of failing" do
      service = create(:service, project: project)
      put project_service_path(project, service), params: { service: { probes_yaml: "livenessProbe: &p\n  periodSeconds: 30\nreadinessProbe: *p\n" } }
      expect(response).to redirect_to(project_services_path(project))
      expect(flash[:alert]).to eq("Service could not be updated: Probes yaml is not valid YAML")
    end
  end

  describe "GET #show" do
    it "shows the Health Probes editor for web services only" do
      get project_service_path(project, create(:service, project: project), tab: "advanced")
      expect(response.body).to include("Health Probes", "Save Health Probes")
      get project_service_path(project, create(:service, :background_service, project: project), tab: "advanced")
      expect(response.body).not_to include("Health Probes")
    end

    it "shows the default probes as visible text, not only a placeholder" do
      get project_service_path(project, create(:service, project: project), tab: "advanced")
      page = Capybara.string(response.body)
      expect(page).to have_css("pre", text: "failureThreshold: 60", visible: :all)
      expect(page).to have_css("pre", text: "timeoutSeconds: 10", visible: :all)
    end
  end
end
