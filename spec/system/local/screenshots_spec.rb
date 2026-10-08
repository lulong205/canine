require "rails_helper"

# Local-only visual parity harness (CI excludes spec/system/local).
# Usage: SCREENSHOTS=before bundle exec rspec spec/system/aa_warmup_spec.rb spec/system/local/screenshots_spec.rb
RSpec.describe "Screenshots", type: :system do
  before { skip "set SCREENSHOTS=<label> to capture" unless ENV["SCREENSHOTS"] }

  let(:account) { create(:account) }
  let(:user) { account.owner }
  let(:cluster) { create(:cluster, account: account, name: "local-qr") }
  let(:project) { create(:project, cluster: cluster, account: account, name: "shop", namespace: "shop") }
  let(:dir) { Rails.root.join("tmp/screenshots", ENV["SCREENSHOTS"].to_s).tap(&:mkpath) }

  def shot(name)
    page.has_no_css?(".loading", wait: 5)
    page.save_screenshot(dir.join("#{name}.png").to_s, full: true)
  end

  it "captures key pages" do
    create(:cluster_package, cluster: cluster, name: "traefik-ingress", status: :installed)
    web = create(:service, project: project, name: "web", healthcheck_url: "/up", allow_public_networking: true,
                           probes_yaml: { "livenessProbe" => { "periodSeconds" => 30 } })
    create(:domain, service: web, domain_name: "app.example.com")
    create(:domain, service: web, domain_name: "*.example.com", need_ssl: false)
    create(:service, :background_service, project: project, name: "worker")
    completed = create(:build, project: project, status: :completed, digest: "sha256:#{"a" * 64}", commit_message: "fix pay later")
    create(:deployment, build: completed, status: :completed)
    failed = create(:build, project: project, status: :failed, commit_message: "bump api client")
    create(:deployment, build: failed, status: :failed)
    create_list(:environment_variable, 2, project: project)
    create(:notifier, project: project, name: "Telegram")
    create(:add_on, cluster: cluster, name: "redis")

    # Cluster access fails fast, so async sections render the same placeholder every run.
    allow(K8::Client).to receive(:new).and_raise(StandardError, "offline")
    stub_request(:any, /icons\.duckduckgo\.com/).to_return(status: 404) # project favicon lookup
    allow_any_instance_of(K8::Kubectl).to receive(:call).and_return("{}")
    allow_any_instance_of(K8::Kubectl).to receive(:apply_yaml)
    allow(K8::VictoriaLogs).to receive(:locate).and_return(K8::VictoriaLogs::Endpoint.new(namespace: "logging", name: "vls", port: 9428))
    allow_any_instance_of(K8::VictoriaLogs).to receive(:search).and_return([
      { time: Time.utc(2026, 10, 8, 3, 0, 1.123r), pod: "web-7d9f-abc12", service: "web", message: "GET /up 200" },
      { time: Time.utc(2026, 10, 8, 3, 0, 0), pod: "worker-5c6b-x1y2z", service: "worker", message: "processed 12 jobs" }
    ])

    page.driver.resize(1440, 900)
    visit new_user_session_path
    shot("01-sign-in")
    sign_in_user(user: user, account: account)

    { "02-projects" => projects_path,
      "03-deployments" => project_deployments_path(project),
      "04-deployment" => project_deployment_path(project, completed) }.each { |name, path| visit path; shot(name) }

    visit project_services_path(project)
    shot("05-services")
    find("input[name='accordion']", match: :first, visible: :all).click # open the web service card (DaisyUI radio overlay)
    find("a[href='#{project_service_path(project, web, tab: 'advanced')}']").click
    page.has_text?("Pod Template Configuration", wait: 5)
    shot("06-service-advanced")

    { "07-environment" => project_environment_variables_path(project),
      "08-metrics" => project_metrics_path(project),
      "09-logs" => project_logs_path(project, live: "0"),
      "10-clusters" => clusters_path,
      "11-cluster-edit" => edit_cluster_path(cluster),
      "12-add-ons" => add_ons_path,
      "13-new-notifier" => new_project_notifier_path(project),
      "14-account-settings" => edit_account_path(account) }.each { |name, path| visit path; shot(name) }

    expect(Dir[dir.join("*.png")].size).to eq(14)
  end
end
