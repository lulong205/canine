# frozen_string_literal: true

require "rails_helper"

RSpec.describe Projects::Services::DomainsController, type: :request do
  include Devise::Test::IntegrationHelpers

  describe "POST #create" do
    let(:project) { create(:project) }
    let(:service) { create(:service, project: project, allow_public_networking: true) }

    before do
      sign_in project.account.owner
    end

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

  describe "DELETE #destroy" do
    let(:account) { create(:account) }
    let(:user) { account.owner }
    let(:cluster) { create(:cluster, account: account) }
    let(:project) { create(:project, cluster: cluster, account: account) }
    let(:service) { create(:service, project: project, status: :healthy) }
    let!(:domain) { create(:domain, service: service, domain_name: "custom.example.com") }

    before do
      sign_in user
    end

    it "destroys the domain, marks the service as updated, and responds to turbo_stream" do
      expect {
        delete project_service_domain_path(project, service, domain), as: :turbo_stream
      }.to change(Domain, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(target="service/#{service.id}/domains"))
      expect(service.reload).to be_updated
    end

    it "destroys the domain and renders partial when requested as html" do
      expect {
        delete project_service_domain_path(project, service, domain)
      }.to change(Domain, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(id="service/#{service.id}/domains"))
      expect(service.reload).to be_updated
    end

    it "fails with 404 when domain belongs to a different service" do
      other_service = create(:service, project: project)
      other_domain = create(:domain, service: other_service)

      expect {
        delete project_service_domain_path(project, service, other_domain)
      }.not_to change(Domain, :count)

      expect(response).to redirect_to(root_path)
    end
  end
end
