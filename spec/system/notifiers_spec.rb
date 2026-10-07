require 'rails_helper'

RSpec.describe "Notifiers", type: :system do
  attr_reader :project

  before do
    result = sign_in_user
    cluster = create(:cluster, account: result[:account])
    @project = create(:project, cluster: cluster, account: result[:account])
  end

  describe "new" do
    it "saves the webhook URL of the selected provider, not of the hidden ones" do
      url = "https://discord.com/api/webhooks/123/abc"

      visit new_project_notifier_path(project)
      fill_in "notifier[name]", with: "Deploy Alerts"
      find("label[for='discord']").click
      find("[data-value='discord'] input[name='notifier[webhook_url]']").set(url)
      click_button "Create Notifier"

      expect(page).to have_content("Deploy Alerts").or have_content("can't be blank")
      expect(page).to have_no_content("can't be blank")
      expect(project.notifiers.sole).to have_attributes(provider_type: "discord", webhook_url: url)
    end
  end
end
