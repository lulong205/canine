require "rails_helper"

RSpec.describe Projects::LogsController, type: :request do
  include Devise::Test::IntegrationHelpers

  let(:project) { create(:project) }
  let!(:web) { create(:service, project: project, name: "web") }
  let(:endpoint) { K8::VictoriaLogs::Endpoint.new(namespace: "logging", name: "vls", port: 9428) }
  let(:row) { { time: Time.utc(2026, 10, 8, 3, 0, 1.123r), pod: "web-1", service: "web", message: "GET /up 200" } }

  before do
    sign_in project.account.owner
    allow(K8::VictoriaLogs).to receive(:locate).and_return(endpoint)
  end

  it "shows log rows" do
    allow_any_instance_of(K8::VictoriaLogs).to receive(:search).and_return([ row ])
    get project_logs_path(project)
    expect(response.body).to include("2026-10-08 03:00:01.123", "web-1", "GET /up 200")
  end

  it "passes valid filters through" do
    expect_any_instance_of(K8::VictoriaLogs).to receive(:search).with(namespace: project.namespace, service: "web", text: "error", range: "24h").and_return([])
    get project_logs_path(project, service: "web", q: "  error  ", range: "24h")
  end

  it "replaces an unknown service and range with the defaults" do
    expect_any_instance_of(K8::VictoriaLogs).to receive(:search).with(namespace: project.namespace, service: nil, text: nil, range: "1h").and_return([])
    get project_logs_path(project, service: "someone-elses", range: "30d")
  end

  it "shows the empty state" do
    allow_any_instance_of(K8::VictoriaLogs).to receive(:search).and_return([])
    get project_logs_path(project, range: "6h")
    expect(response.body).to include("No logs in the last 6h.")
  end

  it "shows the cap note at 500 rows" do
    allow_any_instance_of(K8::VictoriaLogs).to receive(:search).and_return([ row ] * 500)
    get project_logs_path(project)
    expect(response.body).to include("Showing the newest 500 lines. Narrow the search to see older ones.")
  end

  it "shows the not-installed state" do
    allow(K8::VictoriaLogs).to receive(:locate).and_return(nil)
    get project_logs_path(project)
    expect(response.body).to include("VictoriaLogs isn't installed on this cluster.", edit_cluster_path(project.cluster))
  end

  it "shows a kubectl failure instead of failing" do
    allow_any_instance_of(K8::VictoriaLogs).to receive(:search).and_raise(Cli::CommandFailedError, "services \"vls\" is forbidden")
    get project_logs_path(project)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("services &quot;vls&quot; is forbidden")
  end

  it "auto-refreshes only when live" do
    allow_any_instance_of(K8::VictoriaLogs).to receive(:search).and_return([])
    get project_logs_path(project)
    expect(Capybara.string(response.body).find("turbo-frame#logs")["data-controller"]).to eq("refresh-turbo-frame")
    get project_logs_path(project, live: "0")
    expect(Capybara.string(response.body).find("turbo-frame#logs")["data-controller"]).to be_nil
  end

  it "submits filters as a full page visit so the Auto-refresh setting takes effect" do
    allow_any_instance_of(K8::VictoriaLogs).to receive(:search).and_return([])
    get project_logs_path(project)
    form = Capybara.string(response.body).find("form[action='#{project_logs_path(project)}']")
    expect(form["data-turbo-frame"]).to be_nil
  end

  it "puts the Logs tab right after Metrics" do
    allow_any_instance_of(K8::VictoriaLogs).to receive(:search).and_return([])
    get project_logs_path(project)
    hrefs = Capybara.string(response.body).all("[role='tablist'] a").map { |a| URI(a[:href]).path }
    expect(hrefs[hrefs.index(project_metrics_path(project)) + 1]).to eq(project_logs_path(project))
  end
end
