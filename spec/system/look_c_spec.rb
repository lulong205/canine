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
      </div>
    HTML
  end

  def css(selector, prop)
    page.evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json})).#{prop}")
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

    it "raises cards" do
      expect(css("#lc .card", "boxShadow")).to include("24px")
    end

    it "gives plain outline buttons the neutral look" do
      expect(css("#lc .btn-outline:not(.btn-primary)", "borderTopColor")).to eq("rgb(42, 54, 72)")
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
