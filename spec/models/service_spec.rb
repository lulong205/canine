# == Schema Information
#
# Table name: services
#
#  id                      :bigint           not null, primary key
#  allow_public_networking :boolean          default(FALSE)
#  command                 :string
#  container_port          :integer          default(3000)
#  description             :text
#  healthcheck_url         :string
#  last_health_checked_at  :datetime
#  name                    :string           not null
#  pod_yaml                :jsonb
#  probes_yaml             :jsonb
#  replicas                :integer          default(1)
#  service_type            :integer          not null
#  status                  :integer          default("pending")
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  project_id              :bigint           not null
#
# Indexes
#
#  index_services_on_project_id_and_name  (project_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
require 'rails_helper'

RSpec.describe Service, type: :model do
  describe '.permitted_params' do
    it 'converts YAML text to JSON for pod_yaml' do
      yaml_text = "containers:\n  - name: sidecar\n    image: nginx:latest"
      params = ActionController::Parameters.new(
        service: { name: 'test-service', pod_yaml: yaml_text }
      )

      permitted = Service.permitted_params(params)

      expect(permitted[:pod_yaml]).to be_present
      expect(permitted[:pod_yaml]['containers']).to be_an(Array)
      expect(permitted[:pod_yaml]['containers'].first['name']).to eq('sidecar')
      expect(permitted[:pod_yaml]['containers'].first['image']).to eq('nginx:latest')
    end

    it 'handles invalid YAML gracefully' do
      invalid_yaml = "containers:\n  - invalid: ["
      params = ActionController::Parameters.new(
        service: { name: 'test-service', pod_yaml: invalid_yaml }
      )

      allow(Rails.logger).to receive(:error)
      permitted = Service.permitted_params(params)

      expect(Rails.logger).to have_received(:error).with(/Failed to parse pod_yaml/)
      expect(permitted[:pod_yaml]).to eq(invalid_yaml)
    end
  end

  describe "probes_yaml validation" do
    {
      "livenessProbe: [" => "is not valid YAML",
      [ "livenessProbe" ] => "must be a map of startupProbe, livenessProbe, readinessProbe",
      { "liveness" => {}, "startup" => {} } => "has unknown keys: liveness, startup",
      { "livenessProbe" => 5 } => "livenessProbe must be a map or null"
    }.each do |value, message|
      it "rejects #{value.inspect}" do
        service = build(:service, probes_yaml: value)
        expect(service).not_to be_valid
        expect(service.errors[:probes_yaml]).to include(message)
      end
    end

    it "accepts nil and a map of known probes" do
      expect(build(:service, probes_yaml: nil)).to be_valid
      expect(build(:service, probes_yaml: { "startupProbe" => nil, "livenessProbe" => { "periodSeconds" => 30 } })).to be_valid
    end
  end

  describe ".permitted_params probes_yaml" do
    def permitted_probes(value) = Service.new(Service.permitted_params(ActionController::Parameters.new(service: { probes_yaml: value }))).probes_yaml

    it("parses probe YAML text") { expect(permitted_probes("livenessProbe:\n  periodSeconds: 30\n")).to eq("livenessProbe" => { "periodSeconds" => 30 }) }
    it("clears on blank text") { expect(permitted_probes("")).to be_nil }
    it("treats comments only as no override") { expect(permitted_probes("# nothing\n")).to be_nil }
    it("keeps unparseable text for validation") { expect(permitted_probes("livenessProbe: [")).to eq("livenessProbe: [") }

    it "keeps a map from a restored config" do
      expect(permitted_probes({ "startupProbe" => nil, "livenessProbe" => { "periodSeconds" => 30 } }))
        .to eq("startupProbe" => nil, "livenessProbe" => { "periodSeconds" => 30 })
    end
  end
end
