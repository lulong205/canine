require "rails_helper"

RSpec.describe Projects::Services::DomainsController, type: :request do
  include Devise::Test::IntegrationHelpers

  let(:project) { create(:project) }
  let(:service) { create(:service, project: project, allow_public_networking: true) }

  before do
    sign_in project.account.owner
  end

  describe "POST #create" do
    it "saves a domain with Need SSL unchecked" do
      post project_service_domains_path(project, service), params: { domain: { domain_name: "proxied.example.com", need_ssl: "0" } }
      expect(response).to have_http_status(:ok)
      expect(service.domains.sole.need_ssl).to be(false)
      expect(response.body).to include("No SSL")
      expect(response.body).not_to include("Certificate Status")
    end

    it "needs SSL when the param is omitted" do
      post project_service_domains_path(project, service), params: { domain: { domain_name: "secure.example.com" } }
      expect(service.domains.sole.need_ssl).to be(true)
      expect(response.body).to include("Certificate Status")
    end
  end
end
