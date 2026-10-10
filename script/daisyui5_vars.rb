# Rewrites DaisyUI 4 CSS variables (oklch(var(--bc) / 0.1), var(--fallback-…), --rounded-*) to DaisyUI 5 names.
# Usage: ruby script/daisyui5_vars.rb FILE… (rewrites in place, exits 1 if anything DaisyUI 4 is left)
module Daisyui5Vars
  MAP = {
    "p" => "primary", "pc" => "primary-content", "s" => "secondary", "sc" => "secondary-content",
    "a" => "accent", "ac" => "accent-content", "n" => "neutral", "nc" => "neutral-content",
    "b1" => "base-100", "b2" => "base-200", "b3" => "base-300", "bc" => "base-content",
    "in" => "info", "inc" => "info-content", "su" => "success", "suc" => "success-content",
    "wa" => "warning", "wac" => "warning-content", "er" => "error", "erc" => "error-content"
  }.freeze
  RADII = { "box" => "radius-box", "btn" => "radius-field", "badge" => "radius-selector" }.freeze

  OKLCH = %r{oklch\(var\(--([a-z0-9]+)\)(?:\s*/\s*(var\(--[a-z0-9-]+\)|[0-9.]+))?\s*\)}
  REWRITTEN = /color-mix\(in oklab, var\(--color-[a-z0-9-]+\) (?:calc\(var\(--[a-z0-9-]+, 1\) \* 100%\)|[0-9.]+%), transparent\)|var\(--color-[a-z0-9-]+\)/
  FALLBACK = /var\(\s*--fallback-[a-z0-9]+,\s*(#{REWRITTEN})\s*\)/
  LEFTOVER = /oklch\(var\(--[a-z0-9]+\)|--fallback-[a-z0-9]+|--rounded-[a-z]+/

  def self.rewrite(css)
    css = css.gsub(OKLCH) do
      name = MAP[Regexp.last_match(1)]
      next Regexp.last_match(0) unless name

      alpha = Regexp.last_match(2)
      if alpha.nil?
        "var(--color-#{name})"
      else
        amount = alpha.start_with?("var(") ? "calc(#{alpha.sub(/\)\z/, ', 1)')} * 100%)" : format("%g%%", alpha.to_f * 100)
        "color-mix(in oklab, var(--color-#{name}) #{amount}, transparent)"
      end
    end
    css = css.gsub(FALLBACK) { Regexp.last_match(1) }
    css.gsub(/--rounded-(box|btn|badge)\b/) { "--#{RADII[Regexp.last_match(1)]}" }
  end

  def self.leftovers(css)
    css.scan(LEFTOVER)
  end
end

if $PROGRAM_NAME == __FILE__
  left = ARGV.flat_map do |path|
    css = Daisyui5Vars.rewrite(File.read(path))
    File.write(path, css)
    Daisyui5Vars.leftovers(css).map { |snippet| "#{path}: #{snippet}" }
  end
  puts left
  exit(left.empty? ? 0 : 1)
end
