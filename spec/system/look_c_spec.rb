require "rails_helper"

# Computed styles of the look C restyle (app/assets/stylesheets/lookc.css).
# System specs read the built CSS: run `yarn -s build:css` first.
RSpec.describe "Look C styles", type: :system do
  let(:account) { create(:account) }
  let(:cluster) { create(:cluster, account: account) }
  let(:project) { create(:project, cluster: cluster, account: account) }

  let(:fixture) do
    <<~HTML
      <div id="lc">
        <button class="btn btn-primary" disabled>Disabled</button>
        <a class="btn btn-primary" disabled>Disabled link</a>
        <button class="btn btn-outline btn-primary">Outline primary</button>
        <button class="btn btn-outline">Outline</button>
        <button class="btn btn-ghost">Ghost</button>
        <input class="input error">
        <input class="input input-error">
        <input class="input" id="lc-plain">
        <input class="input bg-base-200">
        <input class="input" id="lc-disabled" disabled>
        <div class="card">Card</div>
        <button class="btn btn-outline btn-disabled" disabled>Disabled neutral</button>
        <button class="btn btn-outline border-base-content/20" id="lc-own-border">Search</button>
        <table class="table"><tbody><tr><td class="py-4">Padded</td><td id="lc-td">Plain</td></tr></tbody></table>
        <span class="badge badge-success" id="lc-badge">Deployed</span>
        <span class="badge badge-success" id="lc-badge-icon"><iconify-icon icon="lucide:check-circle" height="14"></iconify-icon> Installed</span>
        <span class="badge badge-info" id="lc-badge-spinner"><span class="loading loading-spinner loading-xs"></span> Installing</span>
        <span class="badge badge-warning" id="lc-badge-busy">Building <iconify-icon class="ml-1 animate-spin" icon="lucide:loader-circle"></iconify-icon></span>
      </div>
    HTML
  end

  def css(selector, prop, pseudo = nil)
    page.evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json}), #{pseudo.to_json}).#{prop}")
  end

  before do
    create(:service, project: project, name: "web") # a project with a service gets the Deploy split button

    # Cluster access fails fast, so the page renders without a cluster.
    allow(K8::Client).to receive(:new).and_raise(StandardError, "offline")
    stub_request(:any, /icons\.duckduckgo\.com/).to_return(status: 404) # project favicon lookup
    allow_any_instance_of(K8::Kubectl).to receive(:call).and_return("{}")

    page.driver.resize(1920, 1080)
    sign_in_user(user: account.owner, account: account)
    visit project_deployments_path(project)
    page.execute_script("document.querySelector('.content-wrapper').insertAdjacentHTML('beforeend', #{fixture.to_json})")
  end

  context "look C" do
    it "puts one gradient on the Deploy split button" do
      expect(css(".join:has(> form .btn-primary)", "backgroundImage")).to include("linear-gradient")
      expect(css(".join form .btn-primary", "backgroundImage")).not_to include("gradient")
    end

    it "lightens the hovered half of the Deploy split button" do
      find(".join form .btn-primary").hover
      expect(find(".join form .btn-primary")).to match_style("background-color" => "rgba(255, 255, 255, 0.1)")
    end

    it "puts a dot on state badges, unless an icon or spinner leads them" do
      expect(css("#lc-badge", "content", "::before")).to eq('""')
      expect(css("#lc-badge-busy", "content", "::before")).to eq('""') # trailing spinner: projects/_status.html.erb
      expect(css("#lc-badge-icon", "content", "::before")).to eq("none") # clusters/cluster_packages/_status.html.erb
      expect(css("#lc-badge-spinner", "content", "::before")).to eq("none")
    end

    it "raises cards" do
      expect(css("#lc .card", "boxShadow")).to include("24px")
    end

    it "gives plain outline buttons the neutral look" do
      expect(css("#lc .btn-outline:not(.btn-primary)", "borderTopColor")).to eq("rgb(42, 54, 72)")
      expect(css("#lc-own-border", "borderTopColor")).to eq("rgb(42, 54, 72)") # shared/_search.html.erb sets its own border colour
    end
  end

  context "guards" do
    it "keeps disabled primary flat" do
      expect(css("#lc .btn-primary[disabled]", "backgroundImage")).not_to include("gradient")
      expect(css("#lc a.btn-primary[disabled]", "backgroundImage")).not_to include("gradient") # link_to ..., disabled: true
    end

    it "keeps outline primary outlined" do
      expect(css("#lc .btn-outline.btn-primary", "backgroundImage")).not_to include("gradient")
    end

    it "keeps disabled neutral buttons borderless" do
      expect(css("#lc .btn-outline.btn-disabled", "borderTopColor")).to eq("rgba(0, 0, 0, 0)") # processes/_pods.html.erb: disabled Shell
    end

    it "keeps a table cell's own padding" do
      expect(css("#lc td.py-4", "paddingTop")).to eq("16px") # add_ons/_index.html.erb
      expect(css("#lc-td", "paddingTop")).to eq("14px")
    end

    it "keeps ghost clear" do
      expect(css("#lc .btn-ghost", "backgroundColor")).to eq("rgba(0, 0, 0, 0)")
    end

    it "keeps the error border" do
      expect(css("#lc .input.error", "borderTopColor")).to eq("rgb(251, 113, 133)")
      expect(css("#lc .input-error", "borderTopColor")).to eq("rgb(251, 113, 133)") # DaisyUI's class, set by k3s_instructions_controller.js
    end

    it "keeps the input focus ring" do
      page.execute_script("document.getElementById('lc-plain').focus()")
      expect(css("#lc-plain", "outlineColor")).to eq("rgb(230, 237, 247)")
    end

    it "keeps an input's own background" do
      expect(css("#lc .input.bg-base-200", "backgroundColor")).to eq("rgb(24, 33, 49)") # registry_selector_controller.js locks the URL field with it
      expect(css("#lc-disabled", "backgroundColor")).to eq("rgb(24, 33, 49)") # DaisyUI's disabled fill
    end

    it "keeps Restart red outline" do
      expect(css("form[action$='/restart'] .btn", "color")).to eq("rgb(251, 113, 133)")
      expect(css("form[action$='/restart'] .btn", "backgroundColor")).to eq("rgba(0, 0, 0, 0)")
    end

    it "fills the width" do
      expect(page.evaluate_script("document.querySelector('.content-wrapper').getBoundingClientRect().width")).to be > 1600 # 1536 with the container cap
      expect(css(".content-wrapper", "paddingLeft")).to eq("32px")
    end
  end
end
