require 'rails_helper'

RSpec.describe K8::Stateless::Deployment do
  let(:project) { create(:project) }
  let(:service) { create(:service, project: project, command: "bin/dev") }
  let(:deployment) { described_class.new(service) }

  it 'merges custom pod spec extras without replacing the primary container' do
    service.update!(pod_yaml: {
      "serviceAccountName" => "builder",
      "containers" => [
        {
          "name" => "debugger",
          "image" => "busybox:1.36"
        }
      ],
      "volumes" => [
        {
          "name" => "cache",
          "emptyDir" => {}
        }
      ]
    })

    yaml = deployment.to_yaml

    expect(yaml).to include("serviceAccountName: builder")
    expect(yaml).to include("name: #{project.name}")
    expect(yaml).to include("name: debugger")
    expect(yaml).to include("name: cache")
  end

  describe 'development environment git clone' do
    let(:parent_project) { create(:project) }
    let(:development_environment_configuration) do
      create(:development_environment_configuration,
        project: parent_project,
        enabled: true,
        workspace_mount_path: "/workspace")
    end

    context 'when in development environment' do
      before do
        development_environment_configuration
        create(:development_environment, child_project: project, parent_project: parent_project)
        project.reload
      end

      it 'includes the git-clone init container' do
        yaml = deployment.to_yaml

        expect(yaml).to include("initContainers:")
        expect(yaml).to include("name: git-clone")
        expect(yaml).to include("image: alpine/git:latest")
        expect(yaml).not_to include("name: rover")
      end

      it 'does not include a rover sidecar' do
        yaml = deployment.to_yaml

        expect(yaml).not_to include("ghcr.io/caninehq/rover")
        expect(yaml).not_to include("restartPolicy: Always")
      end

      it 'mounts project volumes to the git-clone init container' do
        create(:volume, project: project, name: "app-storage", mount_path: "/data")

        yaml = deployment.to_yaml
        clone_section = yaml.split("name: git-clone").last.split("containers:").first

        expect(clone_section).to include("volumeMounts:")
        expect(clone_section).to include("name: app-storage")
        expect(clone_section).to include("mountPath: /data")
      end
    end

    context 'when not in development environment' do
      it 'does not include init containers' do
        yaml = deployment.to_yaml

        expect(yaml).not_to include("name: git-clone")
        expect(yaml).not_to include("initContainers:")
      end
    end
  end

  describe "probes" do
    let(:http) { { "path" => "/up", "port" => 3000 } }
    let(:probes_yaml) { nil }
    let(:service) { create(:service, project: project, healthcheck_url: "/up", probes_yaml: probes_yaml) }
    let(:liveness_default) { { "httpGet" => http, "periodSeconds" => 20, "timeoutSeconds" => 10, "failureThreshold" => 3 } }

    def container = YAML.safe_load(described_class.new(service).to_yaml).dig("spec", "template", "spec", "containers", 0)

    it "renders the default probes" do
      expect(container["startupProbe"]).to eq("httpGet" => http, "periodSeconds" => 5, "failureThreshold" => 60)
      expect(container["livenessProbe"]).to eq(liveness_default)
      expect(container["readinessProbe"]).to eq(liveness_default)
    end

    context "with an empty override" do
      let(:probes_yaml) { {} }

      it "renders the defaults" do
        expect(container["startupProbe"]).to eq("httpGet" => http, "periodSeconds" => 5, "failureThreshold" => 60)
        expect(container["livenessProbe"]).to eq(liveness_default)
        expect(container["readinessProbe"]).to eq(liveness_default)
      end
    end

    context "with a timing override" do
      let(:probes_yaml) { { "livenessProbe" => { "periodSeconds" => 30 } } }

      it "deep-merges it onto the default" do
        expect(container["livenessProbe"]).to eq(liveness_default.merge("periodSeconds" => 30))
      end
    end

    context "with only the httpGet path changed" do
      let(:probes_yaml) { { "readinessProbe" => { "httpGet" => { "path" => "/ready" } } } }

      it "keeps the port" do
        expect(container.dig("readinessProbe", "httpGet")).to eq("path" => "/ready", "port" => 3000)
      end
    end

    context "with a probe set to null" do
      let(:probes_yaml) { { "startupProbe" => nil } }

      it "removes it" do
        expect(container).not_to have_key("startupProbe")
        expect(container["livenessProbe"]).to eq(liveness_default)
      end
    end

    context "with a tcpSocket handler" do
      let(:probes_yaml) { { "livenessProbe" => { "tcpSocket" => { "port" => 3000 } } } }

      it "replaces the default httpGet" do
        expect(container["livenessProbe"]).to eq("tcpSocket" => { "port" => 3000 }, "periodSeconds" => 20, "timeoutSeconds" => 10, "failureThreshold" => 3)
      end
    end

    it "renders no probes for a background service" do
      service = create(:service, :background_service, project: project, healthcheck_url: "/up", probes_yaml: { "livenessProbe" => { "periodSeconds" => 30 } })
      container = YAML.safe_load(described_class.new(service).to_yaml).dig("spec", "template", "spec", "containers", 0)
      expect(container.keys & Service::PROBE_NAMES).to be_empty
    end

    context "without a Health Check URL" do
      let(:service) { create(:service, project: project, healthcheck_url: nil) }

      it "renders no probes" do
        expect(container.keys & Service::PROBE_NAMES).to be_empty
      end
    end
  end
end
