require "rails_helper"

RSpec.describe WebhookBuilder do
  subject(:builder) { described_class.new }

  let(:basic_builder) do
    builder
      .title("My Project")
      .description("Deployment completed")
      .url("https://example.com/deploy/1")
      .status(emoji: "✅", text: "Success", state: :success)
      .widget(label: "Status", value: "✅ Success")
      .widget(label: "Version", value: "1.0.0")
  end

  describe "#build" do
    it "raises error for unknown provider" do
      expect { builder.build(:unknown) }.to raise_error(ArgumentError, /Unknown provider/)
    end
  end

  describe "slack payload" do
    subject(:payload) { basic_builder.build(:slack) }

    it "includes title with emoji" do
      expect(payload[:text]).to eq("✅ *My Project*")
    end

    it "includes attachment with description and color" do
      attachment = payload[:attachments].first
      expect(attachment[:text]).to eq("Deployment completed")
      expect(attachment[:color]).to eq("good")
    end

    it "includes fields from widgets" do
      fields = payload[:attachments].first[:fields]
      expect(fields).to include(hash_including(title: "Version", value: "1.0.0"))
    end

    it "includes action button with url" do
      actions = payload[:attachments].first[:actions]
      expect(actions.first).to include(type: "button", url: "https://example.com/deploy/1")
    end

    it "uses danger color for failed state" do
      payload = builder.status(emoji: "❌", text: "Failed", state: :failed).build(:slack)
      expect(payload[:attachments].first[:color]).to eq("danger")
    end

    it "uses blue color for in_progress state" do
      payload = builder.status(emoji: "🚀", text: "In Progress", state: :in_progress).build(:slack)
      expect(payload[:attachments].first[:color]).to eq("#3B82F6")
    end
  end

  describe "discord payload" do
    subject(:payload) { basic_builder.build(:discord) }

    it "includes embed with title and description" do
      embed = payload[:embeds].first
      expect(embed[:title]).to eq("✅ My Project")
      expect(embed[:description]).to eq("Deployment completed")
    end

    it "includes url in embed" do
      expect(payload[:embeds].first[:url]).to eq("https://example.com/deploy/1")
    end

    it "includes fields from widgets" do
      fields = payload[:embeds].first[:fields]
      expect(fields).to include(hash_including(name: "Version", value: "1.0.0"))
    end

    it "uses green color for success" do
      expect(payload[:embeds].first[:color]).to eq(0x22C55E)
    end

    it "uses red color for failed" do
      payload = builder.status(emoji: "❌", text: "Failed", state: :failed).build(:discord)
      expect(payload[:embeds].first[:color]).to eq(0xEF4444)
    end
  end

  describe "microsoft_teams payload" do
    subject(:payload) { basic_builder.build(:microsoft_teams) }

    it "includes MessageCard structure" do
      expect(payload[:"@type"]).to eq("MessageCard")
      expect(payload[:"@context"]).to eq("http://schema.org/extensions")
    end

    it "includes activity title and subtitle" do
      section = payload[:sections].first
      expect(section[:activityTitle]).to eq("✅ My Project")
      expect(section[:activitySubtitle]).to eq("Deployment completed")
    end

    it "includes facts from widgets" do
      facts = payload[:sections].first[:facts]
      expect(facts).to include(hash_including(name: "Version", value: "1.0.0"))
    end

    it "includes potentialAction with url" do
      action = payload[:potentialAction].first
      expect(action[:"@type"]).to eq("OpenUri")
      expect(action[:targets].first[:uri]).to eq("https://example.com/deploy/1")
    end
  end

  describe "google_chat payload" do
    subject(:payload) { basic_builder.build(:google_chat) }

    it "includes cardsV2 structure" do
      expect(payload[:cardsV2]).to be_an(Array)
      expect(payload[:cardsV2].first[:card]).to be_present
    end

    it "includes header with title and subtitle" do
      header = payload[:cardsV2].first[:card][:header]
      expect(header[:title]).to eq("My Project")
      expect(header[:subtitle]).to eq("Deployment completed")
    end

    it "includes widgets from builder" do
      widgets = payload[:cardsV2].first[:card][:sections].first[:widgets]
      version_widget = widgets.find { |w| w[:decoratedText]&.dig(:topLabel) == "Version" }
      expect(version_widget[:decoratedText][:text]).to eq("1.0.0")
    end

    it "includes button with url" do
      widgets = payload[:cardsV2].first[:card][:sections].first[:widgets]
      button_widget = widgets.find { |w| w[:buttonList] }
      expect(button_widget[:buttonList][:buttons].first[:onClick][:openLink][:url]).to eq("https://example.com/deploy/1")
    end
  end

  describe "without url" do
    subject(:builder_no_url) do
      described_class.new
        .title("My Project")
        .description("Deployment completed")
        .status(emoji: "✅", text: "Success", state: :success)
    end

    it "slack payload has no actions" do
      payload = builder_no_url.build(:slack)
      expect(payload[:attachments].first[:actions]).to be_nil
    end

    it "discord payload has no url" do
      payload = builder_no_url.build(:discord)
      expect(payload[:embeds].first[:url]).to be_nil
    end

    it "teams payload has no potentialAction" do
      payload = builder_no_url.build(:microsoft_teams)
      expect(payload[:potentialAction]).to be_nil
    end

    it "google_chat payload has no button" do
      payload = builder_no_url.build(:google_chat)
      widgets = payload[:cardsV2].first[:card][:sections].first[:widgets]
      expect(widgets.none? { |w| w[:buttonList] }).to be true
    end
  end

  describe "webhook payload" do
    subject(:payload) { basic_builder.event("deployment").build(:webhook) }

    it "has the v1 keys in order" do
      expect(payload.keys).to eq(%i[version event status status_text emoji title message url url_label fields timestamp])
      expect(payload).to include(version: 1, event: "deployment", status: "success", status_text: "Success",
                                 emoji: "✅", title: "My Project", message: "Deployment completed",
                                 url: "https://example.com/deploy/1", url_label: "View Details")
    end

    it "maps every status state to a string" do
      %i[success in_progress failed].each do |state|
        result = builder.status(emoji: "x", text: "x", state: state).build(:webhook)
        expect(result[:status]).to eq(state.to_s)
      end
    end

    it "includes fields with and without links, values as strings" do
      result = builder.widget(label: "SHA", value: "abc1234", link: "https://github.com/o/r/commit/abc1234")
                      .widget(label: "Replicas", value: 3).build(:webhook)
      expect(result[:fields]).to eq([
        { label: "SHA", value: "abc1234", link: "https://github.com/o/r/commit/abc1234" },
        { label: "Replicas", value: "3", link: nil }
      ])
    end

    it "uses null url and url_label when no url was set" do
      expect(builder.build(:webhook)).to include(url: nil, url_label: nil)
    end

    it "has an ISO 8601 timestamp" do
      expect(Time.iso8601(payload[:timestamp])).to be_within(5.seconds).of(Time.current)
    end

    it "does not add event to other providers" do
      expect(basic_builder.event("deployment").build(:slack)).not_to have_key(:event)
      expect(basic_builder.event("deployment").build(:discord)).not_to have_key(:event)
    end
  end
end
