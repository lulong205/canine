require "rails_helper"
require Rails.root.join("script/daisyui5_vars")

RSpec.describe Daisyui5Vars do
  {
    "oklch(var(--p))" => "var(--color-primary)",
    "oklch(var(--bc) / 0.1)" => "color-mix(in oklab, var(--color-base-content) 10%, transparent)",
    "oklch(var(--bc)/0.6)" => "color-mix(in oklab, var(--color-base-content) 60%, transparent)",
    "oklch(var(--b1) / var(--tw-bg-opacity))" => "color-mix(in oklab, var(--color-base-100) calc(var(--tw-bg-opacity, 1) * 100%), transparent)",
    "var(--fallback-bc,oklch(var(--bc)/0.2))" => "color-mix(in oklab, var(--color-base-content) 20%, transparent)",
    "var(--fallback-er,oklch(var(--er)/var(--tw-text-opacity)))" => "color-mix(in oklab, var(--color-error) calc(var(--tw-text-opacity, 1) * 100%), transparent)",
    "border-radius: var(--rounded-box, 1rem)" => "border-radius: var(--radius-box, 1rem)",
    "var(--rounded-btn, 0.5rem)" => "var(--radius-field, 0.5rem)",
    "var(--rounded-badge, 1.9rem)" => "var(--radius-selector, 1.9rem)"
  }.each do |from, to|
    it("rewrites #{from}") { expect(described_class.rewrite(from)).to eq(to) }
  end

  it "unwraps a fallback written across several lines" do
    css = "background-color: var(\n    --fallback-b1,\n    oklch(var(--b1) / var(--tw-bg-opacity))\n  ) !important;"
    expect(described_class.rewrite(css)).to eq("background-color: color-mix(in oklab, var(--color-base-100) calc(var(--tw-bg-opacity, 1) * 100%), transparent) !important;")
  end

  it "reports a fallback it could not unwrap, even across lines" do
    expect(described_class.leftovers("color: var(\n  --fallback-zz,\n  red\n);")).to eq([ "--fallback-zz" ])
  end

  it "maps all 20 DaisyUI 4 colour keys" do
    expect(described_class::MAP.keys).to match_array(%w[p pc s sc a ac n nc b1 b2 b3 bc in inc su suc wa wac er erc])
  end

  it "leaves unrelated CSS alone and reports leftovers" do
    css = "color: red; background: oklch(var(--zz) / 0.1);"
    expect(described_class.rewrite("color: red;")).to eq("color: red;")
    expect(described_class.leftovers(described_class.rewrite(css))).to eq([ "oklch(var(--zz)" ])
  end
end
